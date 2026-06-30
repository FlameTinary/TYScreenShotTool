import XCTest
@testable import TShot

final class AIProBackendClientTests: XCTestCase {

    func test_defaultBackendURLFollowsBuildConfiguration() {
        #if DEBUG
        XCTAssertEqual(AppSettings.backendBaseURLDefaultValue, "http://127.0.0.1:8787")
        #else
        XCTAssertEqual(AppSettings.backendBaseURLDefaultValue, "https://tshot-ai-backend.tshot.workers.dev")
        #endif
    }

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
