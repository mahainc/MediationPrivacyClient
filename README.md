# MediationPrivacyClient

A small TCA dependency client that funnels post-ATT and post-UMP privacy
signals into mediation partner SDKs (AppLovin, Meta Audience Network,
Mintegral). Designed to plug in next to [`mahainc/AdsKit`](https://github.com/mahainc/AdsKit).

`AdsKit`'s `AdsBootstrap` reducer owns ATT + UMP. Once those resolve, the
splash reducer dispatches the user's choice into this client, and the
client fans the call out to whichever partner SDKs your app links.

---

## Why this exists

`mahainc/AdsKit` and `mahainc/MobileAdsClient` link only the
GoogleMobileAds core SDK. Any mediation partner you add (AppLovin, Meta,
Mintegral) ships **its own** privacy / consent API that must be flipped
**after** ATT and UMP resolve — not at app launch, not from a feature
reducer. Doing the flip in the wrong order is a policy violation that
silently suppresses fill rate.

This package gives you one `Sendable` witness with three closures and a
clean `combining(...)` API so you can wire all your linked partners
through a single `@Dependency(\.mediationPrivacyClient)` call site.

## Install

Add the package to your app's `Package.swift`:

```swift
.package(
    url: "https://github.com/mahainc/MediationPrivacyClient.git",
    branch: "main"
),
```

Then attach **only the partners you actually link** to your composition-root
target (typically `AppFeature`):

```swift
.target(
    name: "AppFeature",
    dependencies: [
        .product(name: "MediationPrivacyClient", package: "MediationPrivacyClient"),
        .product(name: "MediationPrivacyClientAppLovin", package: "MediationPrivacyClient"),
        .product(name: "MediationPrivacyClientMeta", package: "MediationPrivacyClient"),
        // ...
    ]
),
```

Each partner product brings its own SDK as a transitive dep, so a
Google-only build links nothing extra. Skip the products you don't need.

## Wire it up

Compose the partners you linked into one witness and register it under
`\.mediationPrivacyClient` (typically in `SceneDelegate.scene(_:willConnectTo:)`
inside `prepareDependencies`):

```swift
import MediationPrivacyClient
import MediationPrivacyClientAppLovin
import MediationPrivacyClientMeta
#if canImport(MTGSDK)
import MTGSDK
#endif

prepareDependencies {
    var partners: [MediationPrivacyClient] = [.appLovin, .meta]
    #if canImport(MTGSDK)
    partners.append(.mintegral { granted in
        await MainActor.run {
            MTGSDK.sharedInstance().consentStatus = granted
        }
    })
    #endif
    $0.mediationPrivacyClient = .combining(partners)
}
```

Then dispatch from your splash reducer once ATT and UMP resolve:

```swift
@Reducer
struct SplashStore {
    @ObservableState
    struct State: Equatable { /* ... */ }

    enum Action {
        case attResolved(ATTrackingManager.AuthorizationStatus)
        case umpResolved(UMPRequestStatus)
        // ...
    }

    @Dependency(\.mediationPrivacyClient) var mediationPrivacy

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .attResolved(status):
                return .run { _ in
                    await mediationPrivacy.setAdvertiserTrackingEnabled(status == .authorized)
                }

            case let .umpResolved(status):
                return .run { _ in
                    await mediationPrivacy.setHasUserConsent(status == .obtained)
                }

            // ...
            }
        }
    }
}
```

For Meta, also call `bootSDK()` from your `AppDelegate` adaptor at
`application(_:didFinishLaunchingWithOptions:)`:

```swift
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { @Dependency(\.mediationPrivacyClient) var client; await client.bootSDK() }
        return true
    }
}
```

## Products

| Product | Links | What it gives you |
|---|---|---|
| `MediationPrivacyClient` | none | The `MediationPrivacyClient` struct, `noop`, `combining`, `mintegral(setHasUserConsent:)` factory, `testValue`/`previewValue`, `\.mediationPrivacyClient` |
| `MediationPrivacyClientAppLovin` | `AppLovinSDK` | `MediationPrivacyClient.appLovin` static factory |
| `MediationPrivacyClientMeta` | `FacebookCore` | `MediationPrivacyClient.meta` static factory (auto-detects FBAudienceNetwork via `#if canImport`) |

## Testing

`testValue` and `previewValue` are both `MediationPrivacyClient.noop`,
so unit tests don't need to override the dependency unless they want
to assert call counts. Use the recording pattern shown in
`Tests/MediationPrivacyClientTests/MediationPrivacyClientTests.swift`.

## Caveats

- **Meta Audience Network on SPM** — Meta does not publish
  `FBAudienceNetwork` via SPM. The `MediationPrivacyClientMeta` target
  pulls only `FacebookCore`. If you need
  `FBAdSettings.setAdvertiserTrackingEnabled(_:)`, link
  `FBAudienceNetwork` via CocoaPods or a third-party SPM mirror in your
  app target — the call is gated behind `#if canImport(FBAudienceNetwork)`.
- **No bundled Mintegral target** —
  `Mintegral-official/MintegralAdSDK-Swift-Package` does not re-export
  `MTGSDK` from its umbrella module, so this package can't ship a typed
  Mintegral target. If your app links Mintegral (typically via
  CocoaPods), use the bring-your-own-setter factory:
  `MediationPrivacyClient.mintegral { granted in MTGSDK.sharedInstance().consentStatus = granted }`.
- **Order matters.** `setAdvertiserTrackingEnabled` MUST run after
  `ATTrackingManager.requestTrackingAuthorization` returns.
  `setHasUserConsent` MUST run after the UMP form completes. Calling
  either at app launch is a policy violation.

## Related

- [`mahainc/AdsKit`](https://github.com/mahainc/AdsKit) — umbrella for
  AdMob, Adjust, UMP, RemoteConfig, Analytic clients.
- [`mahainc/MobileAdsClient`](https://github.com/mahainc/MobileAdsClient) —
  the GMA core wrapper that this client complements.
- [`mahainc/AdRevenueClient`](https://github.com/mahainc/AdRevenueClient) —
  paid-impression bridge.
