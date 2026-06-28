import Foundation

enum AIProSubscriptionProductID {
    static let monthly = "tshot.pro.monthly"
}

struct AIProSubscriptionProduct: Equatable {
    let id: String
    let displayName: String
    let displayPrice: String
    let description: String
}

enum AIProSubscriptionStatus: Equatable {
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
