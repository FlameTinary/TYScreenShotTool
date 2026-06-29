import Foundation

enum AIProSubscriptionProductID {
    static let monthly = "tshot.pro.monthly"
}

enum AIProSettingsSignInCompletionBehavior: Equatable {
    case refreshSubscriptionStatus

    static let afterSuccessfulSignIn: AIProSettingsSignInCompletionBehavior = .refreshSubscriptionStatus
}

struct AIProSubscriptionProduct: Codable, Equatable {
    let id: String
    let displayName: String
    let displayPrice: String
    let description: String
}

enum AIProSubscriptionStatus: Equatable {
    private static let defaultCacheMaxAge: TimeInterval = 24 * 60 * 60

    case notLoaded
    case loading
    case regionUnavailable
    case unavailable
    case unsubscribed(AIProSubscriptionProduct)
    case subscribed(AIProSubscriptionProduct)
    case failed(String)

    var product: AIProSubscriptionProduct? {
        switch self {
        case .unsubscribed(let product), .subscribed(let product):
            return product
        case .notLoaded, .loading, .regionUnavailable, .unavailable, .failed:
            return nil
        }
    }

    var isSubscribed: Bool {
        if case .subscribed = self {
            return true
        }
        return false
    }

    var canStartPurchase: Bool {
        if case .unsubscribed = self {
            return true
        }
        return false
    }

    var canStartRestore: Bool {
        switch self {
        case .regionUnavailable, .loading, .notLoaded:
            return false
        case .unavailable, .unsubscribed, .subscribed, .failed:
            return true
        }
    }

    var needsNetworkRefresh: Bool {
        switch self {
        case .notLoaded, .failed:
            return true
        case .loading, .regionUnavailable, .unavailable, .unsubscribed, .subscribed:
            return false
        }
    }

    static func statusAfterVerifiedPurchase(
        product: AIProSubscriptionProduct,
        backendConfirmed: Bool
    ) -> AIProSubscriptionStatus {
        backendConfirmed
            ? .subscribed(product)
            : .failed(AppText.aiProBackendVerificationFailed)
    }

    static func statusAfterBackendRefresh(
        loadedProduct: AIProSubscriptionProduct?,
        cachedProduct: AIProSubscriptionProduct?,
        backendStatus: String,
        backendProductID: String?
    ) -> AIProSubscriptionStatus {
        let product = loadedProduct ?? cachedProduct
        let isActive = backendStatus == "active" || backendStatus == "grace_period"

        if isActive {
            guard let product else {
                return .unavailable
            }
            return .subscribed(product)
        }

        guard let loadedProduct else {
            return .unavailable
        }
        guard backendProductID == nil || backendProductID == loadedProduct.id else {
            return .unsubscribed(loadedProduct)
        }
        return .unsubscribed(loadedProduct)
    }

    static func cachedStatus(
        in userDefaults: UserDefaults = .standard,
        now: Date = Date(),
        maxAge: TimeInterval = defaultCacheMaxAge
    ) -> AIProSubscriptionStatus? {
        guard let data = userDefaults.data(forKey: AppSettings.aiProSubscriptionStatusCacheKey),
              let cache = try? JSONDecoder().decode(CachedStatus.self, from: data),
              now.timeIntervalSince(cache.cachedAt) <= maxAge else {
            return nil
        }

        switch cache.status {
        case .subscribed:
            return .subscribed(cache.product)
        case .unsubscribed:
            return .unsubscribed(cache.product)
        }
    }

    func saveCachedStatus(
        in userDefaults: UserDefaults = .standard,
        now: Date = Date(),
        maxAge: TimeInterval = defaultCacheMaxAge
    ) {
        guard let cache = CachedStatus(status: self, cachedAt: now) else {
            return
        }
        guard now.timeIntervalSince(cache.cachedAt) <= maxAge,
              let data = try? JSONEncoder().encode(cache) else {
            return
        }
        userDefaults.set(data, forKey: AppSettings.aiProSubscriptionStatusCacheKey)
    }

    static func clearCachedStatus(in userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: AppSettings.aiProSubscriptionStatusCacheKey)
    }
}

private struct CachedStatus: Codable {
    enum StoredStatus: String, Codable {
        case subscribed
        case unsubscribed
    }

    let status: StoredStatus
    let product: AIProSubscriptionProduct
    let cachedAt: Date

    init?(status: AIProSubscriptionStatus, cachedAt: Date) {
        switch status {
        case .subscribed(let product):
            self.status = .subscribed
            self.product = product
        case .unsubscribed(let product):
            self.status = .unsubscribed
            self.product = product
        case .notLoaded, .loading, .regionUnavailable, .unavailable, .failed:
            return nil
        }
        self.cachedAt = cachedAt
    }
}

enum AIProAccessState: Equatable {
    case ready
    case needsLogin
    case needsSubscription
    case regionUnavailable

    static func resolve(
        isSubscriptionAllowed: Bool,
        isSignedIn: Bool,
        subscriptionStatus: AIProSubscriptionStatus
    ) -> AIProAccessState {
        guard isSubscriptionAllowed else {
            return .regionUnavailable
        }
        guard isSignedIn else {
            return .needsLogin
        }
        return subscriptionStatus.isSubscribed ? .ready : .needsSubscription
    }
}

enum AIProSubscriptionPromptAction: Equatable {
    case subscribe
    case restore
    case dismiss
}

struct AIProSubscriptionPromptContent: Equatable {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let primaryAction: AIProSubscriptionPromptAction
    let secondaryButtonTitle: String?
    let secondaryAction: AIProSubscriptionPromptAction?
    let cancelButtonTitle: String?

    init(status: AIProSubscriptionStatus) {
        switch status {
        case .notLoaded, .loading:
            title = AppText.aiProPromptTitle
            message = AppText.aiProSubscriptionLoadingMessage
            primaryButtonTitle = AppText.aiProPromptPrimaryButton
            primaryAction = .dismiss
            secondaryButtonTitle = nil
            secondaryAction = nil
            cancelButtonTitle = nil
        case .regionUnavailable:
            title = AppText.aiProPromptTitle
            message = AppText.aiRegionPolicyBlocked
            primaryButtonTitle = AppText.aiProPromptPrimaryButton
            primaryAction = .dismiss
            secondaryButtonTitle = nil
            secondaryAction = nil
            cancelButtonTitle = nil
        case .unavailable:
            title = AppText.aiProPromptTitle
            message = AppText.aiProSubscriptionUnavailableMessage
            primaryButtonTitle = AppText.aiProRestoreButton
            primaryAction = .restore
            secondaryButtonTitle = nil
            secondaryAction = nil
            cancelButtonTitle = AppText.aiProPromptPrimaryButton
        case .unsubscribed(let product):
            title = AppText.aiProPromptTitle
            message = AppText.aiProSubscriptionOfferMessage(product.displayPrice)
            primaryButtonTitle = AppText.aiProSubscribeButton
            primaryAction = .subscribe
            secondaryButtonTitle = AppText.aiProRestoreButton
            secondaryAction = .restore
            cancelButtonTitle = AppText.aiProNotNowButton
        case .subscribed:
            title = AppText.aiProSubscribedTitle
            message = AppText.aiProSubscribedMessage
            primaryButtonTitle = AppText.aiProPromptPrimaryButton
            primaryAction = .dismiss
            secondaryButtonTitle = nil
            secondaryAction = nil
            cancelButtonTitle = nil
        case .failed(let message):
            title = AppText.aiProPromptTitle
            self.message = AppText.aiProSubscriptionFailedMessage(message)
            primaryButtonTitle = AppText.aiProRestoreButton
            primaryAction = .restore
            secondaryButtonTitle = nil
            secondaryAction = nil
            cancelButtonTitle = AppText.aiProPromptPrimaryButton
        }
    }
}
