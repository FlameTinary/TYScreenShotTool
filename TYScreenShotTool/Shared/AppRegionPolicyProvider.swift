import Foundation
import StoreKit

/// App 端区域策略来源。
///
/// 同步判断优先读取缓存，避免截图工具栏点击时等待 StoreKit。
/// App 启动后会后台刷新 StoreKit storefront 并写入缓存。
struct AppRegionPolicyProvider {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func currentPolicy() -> RegionPolicy {
        #if DEBUG
        if let debugOverride = normalizedStorefrontCode(
            userDefaults.string(forKey: AppSettings.debugStorefrontCodeOverrideKey)
        ) {
            return RegionPolicyResolver.policy(forStorefrontCode: debugOverride)
        }
        #endif

        return RegionPolicyResolver.policy(
            forStorefrontCode: userDefaults.string(forKey: AppSettings.cachedStorefrontCodeKey)
        )
    }

    func refreshStorefrontCache() async {
        guard let storefront = await Storefront.current,
              let storefrontCode = normalizedStorefrontCode(storefront.countryCode) else {
            return
        }

        userDefaults.set(storefrontCode, forKey: AppSettings.cachedStorefrontCodeKey)
    }

    private func normalizedStorefrontCode(_ code: String?) -> String? {
        guard let normalized = code?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(),
            normalized.isEmpty == false else {
            return nil
        }
        return normalized
    }
}
