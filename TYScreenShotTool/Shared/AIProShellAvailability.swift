import Foundation

enum AIProShellSelectionBehavior: Equatable {
    case hidden
    case showGatedMenu
}

/// 海外 AI Pro 壳层的最小状态模型。
///
/// 海外 AI Pro 入口点击后先经过隐私、登录、订阅 gate，再进入 AI 模式菜单。
struct AIProShellAvailability {
    let regionPolicy: RegionPolicy
    let isEntranceSettingEnabled: Bool

    var shouldShowEntry: Bool {
        regionPolicy.isCommercialAIAllowed && isEntranceSettingEnabled
    }

    var selectionBehavior: AIProShellSelectionBehavior {
        shouldShowEntry ? .showGatedMenu : .hidden
    }

    func requestMode(for mode: AIAnalysisMode) -> AIAnalysisMode? {
        nil
    }
}
