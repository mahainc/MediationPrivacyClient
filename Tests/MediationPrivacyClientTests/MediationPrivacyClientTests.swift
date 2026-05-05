import ComposableArchitecture
import XCTest
@testable import MediationPrivacyClient

final class MediationPrivacyClientTests: XCTestCase {
    func testNoopIsSafeDefault() async {
        let client = MediationPrivacyClient.noop
        await client.bootSDK()
        await client.setAdvertiserTrackingEnabled(true)
        await client.setHasUserConsent(true)
    }

    func testCombiningFansOutToEachWitness() async {
        let bootCount = LockIsolated(0)
        let trackingValues = LockIsolated<[Bool]>([])
        let consentValues = LockIsolated<[Bool]>([])

        let recorder = MediationPrivacyClient(
            bootSDK: { bootCount.withValue { $0 += 1 } },
            setAdvertiserTrackingEnabled: { value in
                trackingValues.withValue { $0.append(value) }
            },
            setHasUserConsent: { value in
                consentValues.withValue { $0.append(value) }
            }
        )

        let combined = MediationPrivacyClient.combining(recorder, recorder, recorder)
        await combined.bootSDK()
        await combined.setAdvertiserTrackingEnabled(true)
        await combined.setHasUserConsent(false)

        XCTAssertEqual(bootCount.value, 3)
        XCTAssertEqual(trackingValues.value, [true, true, true])
        XCTAssertEqual(consentValues.value, [false, false, false])
    }

    func testTestValueIsNoop() async {
        let client = withDependencies {
            $0.mediationPrivacyClient = MediationPrivacyClient.testValue
        } operation: {
            @Dependency(\.mediationPrivacyClient) var client
            return client
        }
        await client.bootSDK()
        await client.setAdvertiserTrackingEnabled(true)
        await client.setHasUserConsent(true)
    }
}
