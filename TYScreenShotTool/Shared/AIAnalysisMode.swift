import Foundation

/// AI 分析模式
///
/// 定义截图 AI 分析的不同功能模式，包括报错分析、摘要总结、翻译和界面结构识别。
enum AIAnalysisMode {
    /// 开发报错分析模式
    case developerError
    /// 摘要总结模式
    case summary
    /// 翻译模式，指定目标语言
    case translation(AITranslationLanguage)
    /// 界面结构识别模式
    case interfaceStructure

    /// 顶层菜单显示的模式列表
    ///
    /// 不包含翻译子选项，翻译会在子菜单中展示。
    static let topLevelModes: [AIAnalysisMode] = [
        .developerError,
        .summary,
        .interfaceStructure,
    ]

    /// 菜单显示标题
    ///
    /// 用于 AI 功能菜单按钮显示。
    var menuTitle: String {
        switch self {
        case .developerError:
            return "开发报错分析"
        case .summary:
            return "摘要总结"
        case .interfaceStructure:
            return "界面结构识别"
        case let .translation(language):
            return language.menuTitle
        }
    }

    /// 加载状态提示消息
    ///
    /// 在 AI 分析进行中时显示。
    var loadingMessage: String {
        switch self {
        case .developerError:
            return "AI 正在分析..."
        case .summary:
            return "AI 正在总结..."
        case .interfaceStructure:
            return "AI 正在识别界面结构..."
        case let .translation(language):
            return language.loadingMessage
        }
    }

    /// 结果窗口标题
    ///
    /// 用于 AI 分析结果窗口的标题栏。
    var resultStatusTitle: String {
        switch self {
        case .developerError:
            return "AI 分析结果"
        case .summary:
            return "摘要总结"
        case .interfaceStructure:
            return "界面结构识别"
        case let .translation(language):
            return language.resultStatusTitle
        }
    }

    var secondaryCopyButtonTitle: String {
        switch self {
        case .developerError:
            return "复制建议"
        case .summary:
            return "复制重点"
        case .interfaceStructure:
            return "复制结构"
        case .translation:
            return "复制译文"
        }
    }

    var secondaryCopySuccessMessage: String {
        switch self {
        case .developerError:
            return "建议下一步已复制"
        case .summary:
            return "摘要重点已复制"
        case .interfaceStructure:
            return "界面结构已复制"
        case .translation:
            return "译文已复制"
        }
    }
}
