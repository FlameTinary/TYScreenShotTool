import Foundation

/// App 区域化策略。
///
/// 第一版只基于可注入的 storefront code 判断，不接入真实 StoreKit。
struct RegionPolicy: Equatable {
    let storefrontCode: String?
    let isChinaMainlandMode: Bool
    let isCommercialAIAllowed: Bool
    let isLoginAllowed: Bool
    let isSubscriptionAllowed: Bool
    let isServerAPIAllowed: Bool
}

enum RegionPolicyResolver {
    static func policy(forStorefrontCode storefrontCode: String?) -> RegionPolicy {
        let normalizedCode = storefrontCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard let normalizedCode, normalizedCode.isEmpty == false else {
            return RegionPolicy(
                storefrontCode: nil,
                isChinaMainlandMode: false,
                isCommercialAIAllowed: false,
                isLoginAllowed: false,
                isSubscriptionAllowed: false,
                isServerAPIAllowed: false
            )
        }

        let isChinaMainland = normalizedCode == "CHN"
        let isOverseas = isChinaMainland == false

        return RegionPolicy(
            storefrontCode: normalizedCode,
            isChinaMainlandMode: isChinaMainland,
            isCommercialAIAllowed: isOverseas,
            isLoginAllowed: isOverseas,
            isSubscriptionAllowed: isOverseas,
            isServerAPIAllowed: isOverseas
        )
    }
}
