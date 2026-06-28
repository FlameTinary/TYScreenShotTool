import Foundation

/// 统一收口 AI 商业能力可用性判断。
struct AIAvailabilityService {
    private let regionPolicy: RegionPolicy
    private let userDefaults: UserDefaults

    init(
        regionPolicy: RegionPolicy = AppRegionPolicyProvider().currentPolicy(),
        userDefaults: UserDefaults = .standard
    ) {
        self.regionPolicy = regionPolicy
        self.userDefaults = userDefaults
    }

    var shouldShowCommercialAIEntry: Bool {
        regionPolicy.isCommercialAIAllowed
            && userDefaults.bool(forKey: AppSettings.showAIEntrancesKey)
    }

    var shouldShowAIProShellEntry: Bool {
        AIProShellAvailability(
            regionPolicy: regionPolicy,
            isEntranceSettingEnabled: userDefaults.bool(forKey: AppSettings.showAIEntrancesKey)
        ).shouldShowEntry
    }

    var isServerAIAllowed: Bool {
        regionPolicy.isServerAPIAllowed
    }

    var isSubscriptionAllowed: Bool {
        regionPolicy.isSubscriptionAllowed
    }

    var isDeveloperLocalAIConfigAllowed: Bool {
        regionPolicy.isCommercialAIAllowed && regionPolicy.isServerAPIAllowed
    }
}
