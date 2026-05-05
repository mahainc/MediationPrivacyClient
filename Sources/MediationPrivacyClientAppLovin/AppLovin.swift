import AppLovinSDK
import MediationPrivacyClient

extension MediationPrivacyClient {
    /// Wires the AppLovin SDK consent flags. `bootSDK` is a no-op — AppLovin
    /// initializes itself from the `AppLovinSdkKey` Info.plist value when the
    /// linked Google mediation adapter calls `MobileAds.shared.start(...)`.
    /// You only need to flip `setHasUserConsent` after UMP resolves.
    public static let appLovin = MediationPrivacyClient(
        bootSDK: { },
        setAdvertiserTrackingEnabled: { _ in },
        setHasUserConsent: { granted in
            ALPrivacySettings.setHasUserConsent(granted)
            ALPrivacySettings.setDoNotSell(!granted)
        }
    )
}
