import FacebookCore
import MediationPrivacyClient
import UIKit

#if canImport(FBAudienceNetwork)
import FBAudienceNetwork
#endif

extension MediationPrivacyClient {
    /// Wires the Meta SDK boot + ATT-conditioned advertiser-tracking flag.
    ///
    /// `bootSDK` runs `ApplicationDelegate.shared.application(_:didFinishLaunchingWithOptions:)` —
    /// call this from your iOS app's `UIApplicationDelegate` (or a
    /// `@UIApplicationDelegateAdaptor`-wrapped equivalent).
    ///
    /// `setAdvertiserTrackingEnabled` must run AFTER `ATTrackingManager.requestTrackingAuthorization`
    /// returns. Calling it earlier is a Meta policy violation that silently
    /// suppresses fill rate.
    ///
    /// > `FBAdSettings.setAdvertiserTrackingEnabled(_:)` lives in
    /// > `FBAudienceNetwork`, which Meta does not publish via SPM. The call
    /// > is gated behind `#if canImport(FBAudienceNetwork)` — link the SDK
    /// > via CocoaPods or a third-party SPM mirror in your app target if
    /// > you need it. Without it, only the FacebookCore-side
    /// > `Settings.shared.isAdvertiserTrackingEnabled` is set.
    public static let meta = MediationPrivacyClient(
        bootSDK: {
            await MainActor.run {
                _ = ApplicationDelegate.shared.application(
                    UIApplication.shared,
                    didFinishLaunchingWithOptions: nil
                )
            }
        },
        setAdvertiserTrackingEnabled: { enabled in
            await MainActor.run {
                Settings.shared.isAdvertiserTrackingEnabled = enabled
            }
            #if canImport(FBAudienceNetwork)
            FBAdSettings.setAdvertiserTrackingEnabled(enabled)
            #endif
        },
        setHasUserConsent: { _ in }
    )
}
