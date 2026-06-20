import Foundation

enum AITranslationLanguage: CaseIterable {
    case simplifiedChinese
    case english

    var menuTitle: String {
        switch self {
        case .simplifiedChinese:
            return "翻译成中文"
        case .english:
            return "翻译成英文"
        }
    }

    var resultStatusTitle: String {
        switch self {
        case .simplifiedChinese:
            return "翻译成中文"
        case .english:
            return "翻译成英文"
        }
    }

    var loadingMessage: String {
        switch self {
        case .simplifiedChinese:
            return "AI 正在翻译成中文..."
        case .english:
            return "AI 正在翻译成英文..."
        }
    }
}
