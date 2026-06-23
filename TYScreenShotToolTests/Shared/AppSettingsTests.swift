import XCTest
@testable import TShot

final class AppSettingsTests: XCTestCase {

    // MARK: - Key Constants

    func test_screenshotHotKeyKey_is_not_empty() {
        XCTAssertFalse(AppSettings.screenshotHotKeyKey.isEmpty)
    }

    func test_saveDirectoryPathKey_is_not_empty() {
        XCTAssertFalse(AppSettings.saveDirectoryPathKey.isEmpty)
    }

    func test_saveDirectoryBookmarkDataKey_is_not_empty() {
        XCTAssertFalse(AppSettings.saveDirectoryBookmarkDataKey.isEmpty)
    }

    func test_aiUseVisionTextExtractionKey_is_not_empty() {
        XCTAssertFalse(AppSettings.aiUseVisionTextExtractionKey.isEmpty)
    }

    func test_appLanguageKey_is_not_empty() {
        XCTAssertFalse(AppSettings.appLanguageKey.isEmpty)
    }

    func test_appAppearanceKey_is_not_empty() {
        XCTAssertFalse(AppSettings.appAppearanceKey.isEmpty)
    }

    func test_aiAnalysisAPIKeyKey_is_not_empty() {
        XCTAssertFalse(AppSettings.aiAnalysisAPIKeyKey.isEmpty)
    }

    func test_aiAnalysisBaseURLKey_is_not_empty() {
        XCTAssertFalse(AppSettings.aiAnalysisBaseURLKey.isEmpty)
    }

    func test_aiAnalysisModelKey_is_not_empty() {
        XCTAssertFalse(AppSettings.aiAnalysisModelKey.isEmpty)
    }

    // MARK: - Default Values

    func test_screenshotHotKeyDefaultValue_is_non_empty() {
        XCTAssertFalse(AppSettings.screenshotHotKeyDefaultValue.isEmpty)
    }

    func test_screenshotHotKeyDefaultValue_is_valid() {
        let parsed = ScreenshotHotKey(storageValue: AppSettings.screenshotHotKeyDefaultValue)
        XCTAssertNotNil(parsed)
    }

    func test_aiUseVisionTextExtractionDefaultValue_is_false() {
        XCTAssertFalse(AppSettings.aiUseVisionTextExtractionDefaultValue)
    }

    func test_appLanguageDefaultValue_is_system() {
        XCTAssertEqual(AppSettings.appLanguageDefaultValue, AppLanguage.system.storageValue)
    }

    func test_appAppearanceDefaultValue_is_system() {
        XCTAssertEqual(AppSettings.appAppearanceDefaultValue, AppAppearance.system.storageValue)
    }

    func test_aiAnalysisBaseURLDefaultValue_is_not_empty() {
        XCTAssertFalse(AppSettings.aiAnalysisBaseURLDefaultValue.isEmpty)
    }

    func test_aiAnalysisModelDefaultValue_is_not_empty() {
        XCTAssertFalse(AppSettings.aiAnalysisModelDefaultValue.isEmpty)
    }
}
