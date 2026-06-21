import Foundation

/// AI 翻译目标语言
///
/// 定义 AI 翻译功能支持的目标语言选项。
enum AITranslationLanguage: CaseIterable {
    /// 翻译成简体中文
    case simplifiedChinese
    /// 翻译成英文
    case english

    /// 菜单显示标题
    var menuTitle: String {
        switch self {
        case .simplifiedChinese:
            return "翻译成中文"
        case .english:
            return "翻译成英文"
        }
    }

    /// 结果窗口标题
    var resultStatusTitle: String {
        switch self {
        case .simplifiedChinese:
            return "翻译成中文"
        case .english:
            return "翻译成英文"
        }
    }

    /// 加载状态提示消息
    var loadingMessage: String {
        switch self {
        case .simplifiedChinese:
            return "AI 正在翻译成中文..."
        case .english:
            return "AI 正在翻译成英文..."
        }
    }
}
