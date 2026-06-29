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
            && isEntranceSettingEnabled
    }

    var shouldShowAIProShellEntry: Bool {
        AIProShellAvailability(
            regionPolicy: regionPolicy,
            isEntranceSettingEnabled: isEntranceSettingEnabled
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

    private var isEntranceSettingEnabled: Bool {
        AppSettings.boolValue(
            forKey: AppSettings.showAIEntrancesKey,
            defaultValue: AppSettings.showAIEntrancesDefaultValue,
            userDefaults: userDefaults
        )
    }
}
