import Foundation

enum AIAnalysisMode: CaseIterable {
    case developerError
    case summary

    var menuTitle: String {
        switch self {
        case .developerError:
            return "开发报错分析"
        case .summary:
            return "摘要总结"
        }
    }

    var loadingMessage: String {
        switch self {
        case .developerError:
            return "AI 正在分析..."
        case .summary:
            return "AI 正在总结..."
        }
    }

    var resultStatusTitle: String {
        switch self {
        case .developerError:
            return "AI 分析结果"
        case .summary:
            return "摘要总结"
        }
    }

    var secondaryCopyButtonTitle: String {
        switch self {
        case .developerError:
            return "复制建议"
        case .summary:
            return "复制重点"
        }
    }

    var secondaryCopySuccessMessage: String {
        switch self {
        case .developerError:
            return "建议下一步已复制"
        case .summary:
            return "摘要重点已复制"
        }
    }
}
