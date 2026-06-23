import XCTest
@testable import TShot

final class AppLanguageTests: XCTestCase {

    // MARK: - Storage Value

    func test_storageValue_system() {
        XCTAssertEqual(AppLanguage.system.storageValue, "system")
    }

    func test_storageValue_simplifiedChinese() {
        XCTAssertEqual(AppLanguage.simplifiedChinese.storageValue, "simplifiedChinese")
    }

    func test_storageValue_english() {
        XCTAssertEqual(AppLanguage.english.storageValue, "english")
    }

    // MARK: - Localization Code

    func test_localizationCode_system_is_nil() {
        XCTAssertNil(AppLanguage.system.localizationCode)
    }

    func test_localizationCode_simplifiedChinese() {
        XCTAssertEqual(AppLanguage.simplifiedChinese.localizationCode, "zh-Hans")
    }

    func test_localizationCode_english() {
        XCTAssertEqual(AppLanguage.english.localizationCode, "en")
    }

    func test_localizationCode_japanese() {
        XCTAssertEqual(AppLanguage.japanese.localizationCode, "ja")
    }

    func test_localizationCode_korean() {
        XCTAssertEqual(AppLanguage.korean.localizationCode, "ko")
    }

    func test_localizationCode_german() {
        XCTAssertEqual(AppLanguage.german.localizationCode, "de")
    }

    func test_localizationCode_french() {
        XCTAssertEqual(AppLanguage.french.localizationCode, "fr")
    }

    // MARK: - Resolved (userSelection = .system)

    func test_resolved_system_uses_preferred_zh() {
        let result = AppLanguage.resolved(
            userSelection: .system,
            preferredLanguages: ["zh-Hans", "en-US"]
        )
        XCTAssertEqual(result, .simplifiedChinese)
    }

    func test_resolved_system_uses_preferred_ja() {
        let result = AppLanguage.resolved(
            userSelection: .system,
            preferredLanguages: ["ja-JP", "en-US"]
        )
        XCTAssertEqual(result, .japanese)
    }

    func test_resolved_system_uses_preferred_ko() {
        let result = AppLanguage.resolved(
            userSelection: .system,
            preferredLanguages: ["ko-KR", "en-US"]
        )
        XCTAssertEqual(result, .korean)
    }

    func test_resolved_system_uses_preferred_de() {
        let result = AppLanguage.resolved(
            userSelection: .system,
            preferredLanguages: ["de-DE", "en-US"]
        )
        XCTAssertEqual(result, .german)
    }

    func test_resolved_system_uses_preferred_fr() {
        let result = AppLanguage.resolved(
            userSelection: .system,
            preferredLanguages: ["fr-FR", "en-US"]
        )
        XCTAssertEqual(result, .french)
    }

    func test_resolved_system_uses_preferred_en() {
        let result = AppLanguage.resolved(
            userSelection: .system,
            preferredLanguages: ["en-US"]
        )
        XCTAssertEqual(result, .english)
    }

    func test_resolved_system_falls_back_to_english() {
        let result = AppLanguage.resolved(
            userSelection: .system,
            preferredLanguages: ["es-ES", "pt-BR"]
        )
        XCTAssertEqual(result, .english)
    }

    func test_resolved_system_empty_preferred_falls_back_to_english() {
        let result = AppLanguage.resolved(
            userSelection: .system,
            preferredLanguages: []
        )
        XCTAssertEqual(result, .english)
    }

    // MARK: - Resolved (userSelection = explicit language)

    func test_resolved_explicit_selection_overrides_preferred() {
        let result = AppLanguage.resolved(
            userSelection: .japanese,
            preferredLanguages: ["zh-Hans"]
        )
        XCTAssertEqual(result, .japanese)
    }

    func test_resolved_explicit_english_returns_english() {
        let result = AppLanguage.resolved(
            userSelection: .english,
            preferredLanguages: ["ko-KR"]
        )
        XCTAssertEqual(result, .english)
    }

    // MARK: - OCR Recognition Languages

    func test_ocrLanguages_simplifiedChinese() {
        XCTAssertEqual(AppLanguage.simplifiedChinese.ocrRecognitionLanguages, ["zh-Hans", "zh-Hant", "en-US"])
    }

    func test_ocrLanguages_english() {
        XCTAssertEqual(AppLanguage.english.ocrRecognitionLanguages, ["en-US", "zh-Hans", "zh-Hant"])
    }

    func test_ocrLanguages_japanese() {
        XCTAssertEqual(AppLanguage.japanese.ocrRecognitionLanguages, ["ja-JP", "en-US", "zh-Hans", "zh-Hant"])
    }

    func test_ocrLanguages_korean() {
        XCTAssertEqual(AppLanguage.korean.ocrRecognitionLanguages, ["ko-KR", "en-US", "zh-Hans", "zh-Hant"])
    }

    func test_ocrLanguages_german() {
        XCTAssertEqual(AppLanguage.german.ocrRecognitionLanguages, ["de-DE", "en-US", "zh-Hans", "zh-Hant"])
    }

    func test_ocrLanguages_french() {
        XCTAssertEqual(AppLanguage.french.ocrRecognitionLanguages, ["fr-FR", "en-US", "zh-Hans", "zh-Hant"])
    }

    func test_ocrLanguages_system_falls_back_to_english() {
        XCTAssertEqual(AppLanguage.system.ocrRecognitionLanguages, AppLanguage.english.ocrRecognitionLanguages)
    }

    // MARK: - Supported Display Languages

    func test_supportedDisplayLanguages_does_not_include_system() {
        XCTAssertFalse(AppLanguage.supportedDisplayLanguages.contains(.system))
    }

    func test_supportedDisplayLanguages_count() {
        XCTAssertEqual(AppLanguage.supportedDisplayLanguages.count, 6)
    }
}
