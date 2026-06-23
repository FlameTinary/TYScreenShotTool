import XCTest
@testable import TShot

final class AppLocalizationTests: XCTestCase {

    // MARK: - User Selected Language

    func test_userSelectedLanguage_defaults_to_system() {
        let defaults = UserDefaults.makeIsolated()
        let result = AppLocalization.userSelectedLanguage(userDefaults: defaults)
        XCTAssertEqual(result, .system)
    }

    func test_userSelectedLanguage_reads_stored_value() {
        let defaults = UserDefaults.makeIsolated()
        defaults.set(AppLanguage.english.storageValue, forKey: AppSettings.appLanguageKey)
        let result = AppLocalization.userSelectedLanguage(userDefaults: defaults)
        XCTAssertEqual(result, .english)
    }

    func test_userSelectedLanguage_reads_japanese() {
        let defaults = UserDefaults.makeIsolated()
        defaults.set(AppLanguage.japanese.storageValue, forKey: AppSettings.appLanguageKey)
        let result = AppLocalization.userSelectedLanguage(userDefaults: defaults)
        XCTAssertEqual(result, .japanese)
    }

    func test_userSelectedLanguage_invalid_value_falls_back_to_system() {
        let defaults = UserDefaults.makeIsolated()
        defaults.set("invalidLanguage", forKey: AppSettings.appLanguageKey)
        let result = AppLocalization.userSelectedLanguage(userDefaults: defaults)
        XCTAssertEqual(result, .system)
    }

    func test_userSelectedLanguage_empty_value_falls_back_to_system() {
        let defaults = UserDefaults.makeIsolated()
        defaults.set("", forKey: AppSettings.appLanguageKey)
        let result = AppLocalization.userSelectedLanguage(userDefaults: defaults)
        XCTAssertEqual(result, .system)
    }

    // MARK: - Current Language

    func test_currentLanguage_resolves_system_to_preferred() {
        let defaults = UserDefaults.makeIsolated()
        // No language set → defaults to .system → resolves via preferredLanguages
        let result = AppLocalization.currentLanguage(
            userDefaults: defaults,
            preferredLanguages: ["zh-Hans"]
        )
        XCTAssertEqual(result, .simplifiedChinese)
    }

    func test_currentLanguage_uses_explicit_selection() {
        let defaults = UserDefaults.makeIsolated()
        defaults.set(AppLanguage.german.storageValue, forKey: AppSettings.appLanguageKey)
        let result = AppLocalization.currentLanguage(
            userDefaults: defaults,
            preferredLanguages: ["zh-Hans"]
        )
        XCTAssertEqual(result, .german)
    }

    func test_currentLanguage_system_falls_back_to_english() {
        let defaults = UserDefaults.makeIsolated()
        let result = AppLocalization.currentLanguage(
            userDefaults: defaults,
            preferredLanguages: ["es-ES"]
        )
        XCTAssertEqual(result, .english)
    }
}
