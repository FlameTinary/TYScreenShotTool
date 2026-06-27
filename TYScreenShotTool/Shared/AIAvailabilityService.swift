import Foundation

/// 统一收口 AI 商业能力可用性判断。
struct AIAvailabilityService {
    private let regionPolicy: RegionPolicy
    private let userDefaults: UserDefaults

    init(
        regionPolicy: RegionPolicy = RegionPolicyResolver.policy(forStorefrontCode: nil),
        userDefaults: UserDefaults = .standard
    ) {
        self.regionPolicy = regionPolicy
        self.userDefaults = userDefaults
    }

    var shouldShowCommercialAIEntry: Bool {
        regionPolicy.isCommercialAIAllowed
            && userDefaults.bool(forKey: AppSettings.showAIEntrancesKey)
    }

    var isServerAIAllowed: Bool {
        regionPolicy.isServerAPIAllowed
    }

    var isDeveloperLocalAIConfigAllowed: Bool {
        regionPolicy.isCommercialAIAllowed && regionPolicy.isServerAPIAllowed
    }
}
