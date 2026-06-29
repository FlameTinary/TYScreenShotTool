import XCTest
@testable import TShot

final class AIProBackendClientTests: XCTestCase {

    func test_defaultBaseURLUsesConfiguredBackendURL() {
        let defaults = UserDefaults.makeIsolated()
        defaults.set("https://staging.example.com/api", forKey: AppSettings.backendBaseURLKey)

        let url = AIProBackendClient.defaultBaseURL(userDefaults: defaults)

        XCTAssertEqual(url.absoluteString, "https://staging.example.com/api")
    }

    func test_defaultBaseURLFallsBackWhenConfiguredURLIsInvalid() {
        let defaults = UserDefaults.makeIsolated()
        defaults.set("not a url", forKey: AppSettings.backendBaseURLKey)

        let url = AIProBackendClient.defaultBaseURL(userDefaults: defaults)

        XCTAssertEqual(url.absoluteString, AppSettings.backendBaseURLDefaultValue)
    }
}
