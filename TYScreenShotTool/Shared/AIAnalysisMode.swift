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
