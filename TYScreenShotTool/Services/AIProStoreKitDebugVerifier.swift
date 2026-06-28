import Foundation

#if DEBUG
@MainActor
enum AIProStoreKitDebugVerifier {
    enum Mode: String {
        case load
        case purchase
        case restore
    }

    static func run(mode: Mode) async {
        await run(mode: mode, subscriptionService: .shared)
    }

    static func run(mode: Mode, subscriptionService: AIProSubscriptionService) async {
        print("[AIProStoreKitVerification] mode: \(mode.rawValue)")
        subscriptionService.startTransactionListener()

        switch mode {
        case .load:
            let status = await subscriptionService.refreshStatus()
            print("[AIProStoreKitVerification] refreshStatus: \(status.debugSummary)")
        case .purchase:
            _ = await subscriptionService.refreshStatus()
            let status = await subscriptionService.purchaseMonthly()
            print("[AIProStoreKitVerification] purchaseMonthly: \(status.debugSummary)")
        case .restore:
            let status = await subscriptionService.restorePurchases()
            print("[AIProStoreKitVerification] restorePurchases: \(status.debugSummary)")
        }
    }
}

private extension AIProSubscriptionStatus {
    var debugSummary: String {
        switch self {
        case .notLoaded:
            return "notLoaded"
        case .loading:
            return "loading"
        case .regionUnavailable:
            return "regionUnavailable"
        case .unavailable:
            return "unavailable"
        case .unsubscribed(let product):
            return "unsubscribed id=\(product.id) price=\(product.displayPrice)"
        case .subscribed(let product):
            return "subscribed id=\(product.id) price=\(product.displayPrice)"
        case .failed(let message):
            return "failed message=\(message)"
        }
    }
}
#endif
