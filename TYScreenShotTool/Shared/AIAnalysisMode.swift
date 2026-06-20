import Foundation

enum AIAnalysisMode {
    case developerError
    case summary
    case translation(AITranslationLanguage)
    case interfaceStructure

    static let topLevelModes: [AIAnalysisMode] = [
        .developerError,
        .summary,
        .interfaceStructure,
    ]

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
