import Dependencies
import Foundation

/// A TCA dependency client that funnels the post-ATT and post-UMP privacy
/// signals into mediation partner SDKs (AppLovin, Meta Audience Network,
/// Mintegral, ...). Lives next to `mahainc/AdsKit` — `AdsBootstrap` owns
/// ATT + UMP, and the splash reducer dispatches the resolved values into
/// these closures.
///
/// The base module ships only the witness shape and a `noop` value. Per-partner
/// witnesses are vended as `MediationPrivacyClientAppLovin`,
/// `MediationPrivacyClientMeta`, and `MediationPrivacyClientMintegral` —
/// link only the partners your app actually mediates with.
///
/// Compose multiple partners via `MediationPrivacyClient.combining(_:)`.
public struct MediationPrivacyClient: Sendable {
    /// Boots SDKs that need an explicit `application(_:didFinishLaunchingWithOptions:)`
    /// hand-off (Meta). Call from your AppDelegate adaptor at launch.
    public var bootSDK: @Sendable () async -> Void

    /// Sets the partner-specific advertiser-tracking flag. Must be called
    /// **after** ATT resolves with the user's choice (`status == .authorized`).
    public var setAdvertiserTrackingEnabled: @Sendable (Bool) async -> Void

    /// Sets the partner-specific GDPR consent flag. Must be called **after**
    /// the UMP form completes (`consentStatus == .obtained`).
    public var setHasUserConsent: @Sendable (Bool) async -> Void

    public init(
        bootSDK: @escaping @Sendable () async -> Void,
        setAdvertiserTrackingEnabled: @escaping @Sendable (Bool) async -> Void,
        setHasUserConsent: @escaping @Sendable (Bool) async -> Void
    ) {
        self.bootSDK = bootSDK
        self.setAdvertiserTrackingEnabled = setAdvertiserTrackingEnabled
        self.setHasUserConsent = setHasUserConsent
    }
}

// MARK: - Composing partner witnesses

extension MediationPrivacyClient {
    /// Builds a single witness that fans every call out to each partner in
    /// the order provided. Use this in your AppFeature to register all
    /// linked partners under `\.mediationPrivacyClient`.
    public static func combining(_ clients: [MediationPrivacyClient]) -> Self {
        Self(
            bootSDK: {
                for client in clients {
                    await client.bootSDK()
                }
            },
            setAdvertiserTrackingEnabled: { enabled in
                for client in clients {
                    await client.setAdvertiserTrackingEnabled(enabled)
                }
            },
            setHasUserConsent: { granted in
                for client in clients {
                    await client.setHasUserConsent(granted)
                }
            }
        )
    }

    public static func combining(_ clients: MediationPrivacyClient...) -> Self {
        combining(clients)
    }
}

// MARK: - Mintegral factory

extension MediationPrivacyClient {
    /// Bring-your-own-setter Mintegral witness. Mintegral's SPM package
    /// (`Mintegral-official/MintegralAdSDK-Swift-Package`) does not
    /// re-export `MTGSDK` from its umbrella module, so this package
    /// can't ship a typed Mintegral target. If your app links Mintegral
    /// (typically via CocoaPods), pass the consent setter yourself:
    ///
    /// ```swift
    /// import MTGSDK
    ///
    /// let mintegral = MediationPrivacyClient.mintegral { granted in
    ///     await MainActor.run {
    ///         MTGSDK.sharedInstance().consentStatus = granted
    ///     }
    /// }
    /// ```
    public static func mintegral(
        setHasUserConsent: @escaping @Sendable (Bool) async -> Void
    ) -> MediationPrivacyClient {
        MediationPrivacyClient(
            bootSDK: { },
            setAdvertiserTrackingEnabled: { _ in },
            setHasUserConsent: setHasUserConsent
        )
    }
}

// MARK: - Default witnesses

extension MediationPrivacyClient {
    /// All closures are no-ops. Safe default for builds without any
    /// mediation partner linked. Also used as `testValue` and `previewValue`.
    public static let noop = Self(
        bootSDK: { },
        setAdvertiserTrackingEnabled: { _ in },
        setHasUserConsent: { _ in }
    )
}

extension MediationPrivacyClient: TestDependencyKey {
    public static let testValue = noop
    public static let previewValue = noop
}

extension DependencyValues {
    public var mediationPrivacyClient: MediationPrivacyClient {
        get { self[MediationPrivacyClient.self] }
        set { self[MediationPrivacyClient.self] = newValue }
    }
}
