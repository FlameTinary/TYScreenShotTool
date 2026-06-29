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
            return AppText.aiModeDeveloperError
        case .summary:
            return AppText.aiModeSummary
        case .interfaceStructure:
            return AppText.aiModeInterfaceStructure
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
            return AppText.aiLoadingDeveloperError
        case .summary:
            return AppText.aiLoadingSummary
        case .interfaceStructure:
            return AppText.aiLoadingInterfaceStructure
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
            return AppText.aiResultTitle
        case .summary:
            return AppText.aiResultSummaryTitle
        case .interfaceStructure:
            return AppText.aiResultInterfaceStructureTitle
        case let .translation(language):
            return language.resultStatusTitle
        }
    }

    /// Feature 53.9：传递给后端的 prompt，用于 AI 分析时说明请求意图
    var backendPrompt: String? {
        switch self {
        case .developerError:
            return "分析这个截图中出现的开发报错信息，给出原因和解决建议。"
        case .summary:
            return "总结这个截图中的主要内容，提取关键要点。"
        case .translation(let language):
            switch language {
            case .simplifiedChinese:
                return "将截图中的文字翻译成简体中文。"
            case .english:
                return "将截图中的文字翻译成英文。"
            }
        case .interfaceStructure:
            return "分析这个截图的界面结构，描述其中的组件、布局和交互方式。"
        }
    }

    var secondaryCopyButtonTitle: String {
        switch self {
        case .developerError:
            return AppText.aiResultCopySuggestion
        case .summary:
            return AppText.aiResultCopySummary
        case .interfaceStructure:
            return AppText.aiResultCopyStructure
        case .translation:
            return AppText.aiResultCopyTranslation
        }
    }

    var secondaryCopySuccessMessage: String {
        switch self {
        case .developerError:
            return AppText.aiResultCopiedSuggestion
        case .summary:
            return AppText.aiResultCopiedSummary
        case .interfaceStructure:
            return AppText.aiResultCopiedStructure
        case .translation:
            return AppText.aiResultCopiedTranslation
        }
    }
}
