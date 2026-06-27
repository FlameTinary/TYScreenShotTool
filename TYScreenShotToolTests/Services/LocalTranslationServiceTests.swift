import XCTest
@testable import TShot

@MainActor
final class LocalTranslationServiceTests: XCTestCase {

    // MARK: - seemsChineseText

    func test_seemsChineseText_pureChinese_returnsTrue() {
        let text = "这是一段纯中文文本"
        XCTAssertTrue(LocalTranslationService.seemsChineseText(text))
    }

    func test_seemsChineseText_englishText_returnsFalse() {
        let text = "This is a pure English paragraph without any Chinese characters."
        XCTAssertFalse(LocalTranslationService.seemsChineseText(text))
    }

    func test_seemsChineseText_mixedMoreChinese_returnsTrue() {
        let text = "这是一段中文English混合，中文占大多数内容。"
        XCTAssertTrue(LocalTranslationService.seemsChineseText(text))
    }

    func test_seemsChineseText_mixedMoreEnglish_returnsFalse() {
        let text = "This is mostly English text with 少量中文 mixed in."
        XCTAssertFalse(LocalTranslationService.seemsChineseText(text))
    }

    func test_seemsChineseText_emptyString_returnsFalse() {
        XCTAssertFalse(LocalTranslationService.seemsChineseText(""))
    }

    func test_seemsChineseText_shortWithChinese_returnsTrue() {
        // "你好" — 2 out of 2 chars are Chinese, > max(3, 2/4=0) → 2 > 3 = false
        // 2 > 3 为 false, 所以短中文应返回 false
        // 边界：5 个汉字 → 5 > max(3, 5/4=1) = 5 > 3 → true
        let text = "你好世界！"
        XCTAssertTrue(LocalTranslationService.seemsChineseText(text))
    }

    func test_seemsChineseText_shortChinese_underThreshold_returnsFalse() {
        // 只有 2 个汉字，2 > max(3, 2/4=0) → false
        let text = "你好"
        XCTAssertFalse(LocalTranslationService.seemsChineseText(text))
    }

    func test_seemsChineseText_numbersAndSymbols_returnsFalse() {
        let text = "12345!@#$%"
        XCTAssertFalse(LocalTranslationService.seemsChineseText(text))
    }

    func test_seemsChineseText_vietnameseText_returnsFalse() {
        let text = "Xin chào, tôi là nhà phát triển phần mềm."
        XCTAssertFalse(LocalTranslationService.seemsChineseText(text))
    }

    func test_seemsChineseText_japaneseText_returnsFalse() {
        let text = "これは日本語のテキストです。"
        // 日文的平假名/片假名不在 0x4E00-0x9FFF 范围，不认为是中文
        XCTAssertFalse(LocalTranslationService.seemsChineseText(text))
    }

    func test_seemsChineseText_emojiOnly_returnsFalse() {
        let text = "😀🎉🚀🔥"
        XCTAssertFalse(LocalTranslationService.seemsChineseText(text))
    }

    // MARK: - fallbackSourceLanguage

    func test_fallbackSourceLanguage_pureEnglish_returnsEN() {
        let text = "View major documentation updates and highlights, browse ongoing updates from frameworks over time, and jump to the latest release notes."
        let result = LocalTranslationService.fallbackSourceLanguage(for: text)
        XCTAssertEqual(result?.languageCode?.identifier, "en")
    }

    func test_fallbackSourceLanguage_englishWithPunctuation_returnsEN() {
        let text = "This is a test. It has more than 10 ASCII letters!"
        let result = LocalTranslationService.fallbackSourceLanguage(for: text)
        XCTAssertEqual(result?.languageCode?.identifier, "en")
    }

    func test_fallbackSourceLanguage_shortEnglish_underThreshold_returnsNil() {
        // ASCII 字母只有 10 个，阈值 > 10，不够
        let text = "Hlwrdabcd" // 10 letters
        let result = LocalTranslationService.fallbackSourceLanguage(for: text)
        XCTAssertNil(result)
    }

    func test_fallbackSourceLanguage_shortEnglish_atThreshold_returnsEN() {
        // ASCII 字母 11 个，超过阈值 > 10
        let text = "Hlwrdabcdef" // 11 letters
        let result = LocalTranslationService.fallbackSourceLanguage(for: text)
        XCTAssertEqual(result?.languageCode?.identifier, "en")
    }

    func test_fallbackSourceLanguage_veryShortEnglish_returnsNil() {
        // 只有几个字母，不超过 10
        let text = "Hi there"
        let result = LocalTranslationService.fallbackSourceLanguage(for: text)
        XCTAssertNil(result)
    }

    func test_fallbackSourceLanguage_pureChinese_returnsZH() {
        let text = "查看主要文档更新和高亮，浏览框架持续更新，并跳转到最新版本发布说明。"
        let result = LocalTranslationService.fallbackSourceLanguage(for: text)
        XCTAssertEqual(result?.languageCode?.identifier, "zh")
    }

    func test_fallbackSourceLanguage_chineseWithEnglish_returnsZH() {
        let text = "这是一段中文与 English 混合的文本。"
        let result = LocalTranslationService.fallbackSourceLanguage(for: text)
        XCTAssertEqual(result?.languageCode?.identifier, "zh")
    }

    func test_fallbackSourceLanguage_numbersAndSymbols_returnsNil() {
        let text = "12345!@#$%^&*()"
        let result = LocalTranslationService.fallbackSourceLanguage(for: text)
        XCTAssertNil(result)
    }

    func test_fallbackSourceLanguage_emptyString_returnsNil() {
        let result = LocalTranslationService.fallbackSourceLanguage(for: "")
        XCTAssertNil(result)
    }

    func test_fallbackSourceLanguage_emojiOnly_returnsNil() {
        let text = "😀🎉🚀🔥⭐"
        let result = LocalTranslationService.fallbackSourceLanguage(for: text)
        XCTAssertNil(result)
    }

    func test_fallbackSourceLanguage_japaneseText_returnsNil() {
        // 纯假名不含汉字，不在 CJK 0x4E00-0x9FFF 范围也不在 ASCII 范围
        let text = "これはにほんごのテキストです。かいはつしゃむけのさいしんじょうほうをごかくにんください。"
        let result = LocalTranslationService.fallbackSourceLanguage(for: text)
        XCTAssertNil(result)
    }

    func test_fallbackSourceLanguage_koreanText_returnsNil() {
        let text = "이것은 한국어 텍스트입니다."
        let result = LocalTranslationService.fallbackSourceLanguage(for: text)
        // 韩文（谚文）不在检测范围内
        XCTAssertNil(result)
    }

    func test_fallbackSourceLanguage_germanText_returnsEN() {
        let text = "Dies ist ein deutscher Text mit ausreichend vielen Buchstaben."
        let result = LocalTranslationService.fallbackSourceLanguage(for: text)
        // ASCII 字母足够多 → en
        XCTAssertEqual(result?.languageCode?.identifier, "en")
    }

    func test_fallbackSourceLanguage_chineseFirst_precedesEnglish() {
        // 既有中文又有英文，中文占比 > 1/4 → 优先判断为中文
        let text = "这是一段中文English混合中文优先MoreEnglishText."
        let result = LocalTranslationService.fallbackSourceLanguage(for: text)
        XCTAssertEqual(result?.languageCode?.identifier, "zh")
    }

    // MARK: - userFriendlyMessage (NSError 路径)

    func test_userFriendlyMessage_downloadError_returnsDownloadPrompt() {
        let error = NSError(
            domain: "TranslationErrorDomain",
            code: 16,
            userInfo: [NSLocalizedDescriptionKey: "Translation resources need to be downloaded"]
        )
        let message = LocalTranslationService.userFriendlyMessage(for: error)
        XCTAssertTrue(message.contains("下载"), "Download 错误应提示下载语言包，实际: \(message)")
    }

    func test_userFriendlyMessage_identifyError_returnsIdentifyPrompt() {
        let error = NSError(
            domain: "TranslationErrorDomain",
            code: 21,
            userInfo: [NSLocalizedDescriptionKey: "Cannot identify source language from the provided text"]
        )
        let message = LocalTranslationService.userFriendlyMessage(for: error)
        XCTAssertTrue(message.contains("识别"), "无法识别语言应提示截取更清晰文字，实际: \(message)")
    }

    func test_userFriendlyMessage_unsupportedLanguage_returnsUnsupportedPrompt() {
        let error = NSError(
            domain: "TranslationErrorDomain",
            code: 99,
            userInfo: [NSLocalizedDescriptionKey: "unsupported language pair"]
        )
        let message = LocalTranslationService.userFriendlyMessage(for: error)
        XCTAssertTrue(message.contains("暂不支持"), "unsupported 错误应提示语言暂不支持，实际: \(message)")
    }

    func test_userFriendlyMessage_nothingToTranslate_returnsEmptyPrompt() {
        let error = NSError(
            domain: "TranslationErrorDomain",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "nothing to translate"]
        )
        let message = LocalTranslationService.userFriendlyMessage(for: error)
        XCTAssertNotNil(message)
        XCTAssertFalse(message.isEmpty)
    }

    func test_userFriendlyMessage_genericError_returnsGenericPrompt() {
        let error = NSError(
            domain: "NSUnknownErrorDomain",
            code: -1,
            userInfo: nil
        )
        let message = LocalTranslationService.userFriendlyMessage(for: error)
        // 对不匹配任何条件的错误，应返回兜底 "翻译失败，请稍后重试。" 或本地化兜底
        XCTAssertNotNil(message)
        XCTAssertFalse(message.isEmpty)
    }

    func test_userFriendlyMessage_code16_noDescription_returnsDownloadPrompt() {
        let error = NSError(
            domain: "TranslationErrorDomain",
            code: 16,
            userInfo: [NSLocalizedDescriptionKey: "some error"]
        )
        let message = LocalTranslationService.userFriendlyMessage(for: error)
        XCTAssertTrue(message.contains("下载"), "Code 16 应提示下载语言包，实际: \(message)")
    }

    func test_userFriendlyMessage_identifyInDescription_returnsIdentifyPrompt() {
        let error = NSError(
            domain: "CustomDomain",
            code: 999,
            userInfo: [NSLocalizedDescriptionKey: "Failed to identify the language of the input text"]
        )
        let message = LocalTranslationService.userFriendlyMessage(for: error)
        XCTAssertTrue(message.contains("识别"), "description 含 identify 应提示识别错误，实际: \(message)")
    }

    // MARK: - 集成场景

    func test_englishText_fullFlow_detectedAsEnglish() {
        let ocrText = "View major documentation updates and highlights, browse ongoing updates from frameworks over time, and jump to the latest release notes."

        let detectedSource = LocalTranslationService.fallbackSourceLanguage(for: ocrText)
        XCTAssertEqual(detectedSource?.languageCode?.identifier, "en")

        let isChinese = LocalTranslationService.seemsChineseText(ocrText)
        XCTAssertFalse(isChinese, "英文 OCR 文本不应被认为是中文")
    }

    func test_chineseText_fullFlow_detectedAsChinese() {
        let ocrText = "查看主要文档更新和高亮，浏览框架持续更新，并跳转到最新版本发布说明。"

        let detectedSource = LocalTranslationService.fallbackSourceLanguage(for: ocrText)
        XCTAssertEqual(detectedSource?.languageCode?.identifier, "zh")

        let isChinese = LocalTranslationService.seemsChineseText(ocrText)
        XCTAssertTrue(isChinese, "中文 OCR 文本应被识别为中文")
    }
}
