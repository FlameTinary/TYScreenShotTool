import Foundation

/// App 端区域策略来源。
///
/// 第一版不读取 StoreKit storefront，只提供 Debug 本地覆盖能力，方便验证 CHN / 海外 / unknown 分支。
struct AppRegionPolicyProvider {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func currentPolicy() -> RegionPolicy {
        #if DEBUG
        let debugOverride = userDefaults.string(forKey: AppSettings.debugStorefrontCodeOverrideKey)
        return RegionPolicyResolver.policy(forStorefrontCode: debugOverride)
        #else
        return RegionPolicyResolver.policy(forStorefrontCode: nil)
        #endif
    }
}
