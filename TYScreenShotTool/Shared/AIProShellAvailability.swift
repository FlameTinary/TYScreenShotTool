import Foundation

enum AIProShellSelectionBehavior: Equatable {
    case hidden
    case showPrompt
}

/// 海外 AI Pro 壳层的最小状态模型。
///
/// 本阶段只负责展示入口与说明，不会把点击行为转换成真实 AI 请求。
struct AIProShellAvailability {
    let regionPolicy: RegionPolicy
    let isEntranceSettingEnabled: Bool

    var shouldShowEntry: Bool {
        regionPolicy.isCommercialAIAllowed && isEntranceSettingEnabled
    }

    var selectionBehavior: AIProShellSelectionBehavior {
        shouldShowEntry ? .showPrompt : .hidden
    }

    func requestMode(for mode: AIAnalysisMode) -> AIAnalysisMode? {
        nil
    }
}
