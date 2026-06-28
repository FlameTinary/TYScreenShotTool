import Foundation
import StoreKit

@MainActor
final class AIProSubscriptionService {
    static let shared = AIProSubscriptionService()

    private var monthlyProduct: Product?
    private var transactionUpdatesTask: Task<Void, Never>?

    private(set) var status: AIProSubscriptionStatus = .notLoaded

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func startTransactionListener() {
        guard transactionUpdatesTask == nil else {
            return
        }

        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else {
                    return
                }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                _ = await self.refreshStatus()
            }
        }
    }

    func refreshStatus() async -> AIProSubscriptionStatus {
        status = .loading

        do {
            let products = try await Product.products(for: [AIProSubscriptionProductID.monthly])
            guard let product = products.first else {
                monthlyProduct = nil
                status = .unavailable
                return status
            }

            monthlyProduct = product
            let viewModel = makeProductViewModel(from: product)
            status = await hasVerifiedEntitlement(for: product.id)
                ? .subscribed(viewModel)
                : .unsubscribed(viewModel)
            return status
        } catch {
            status = .failed(error.localizedDescription)
            return status
        }
    }

    func purchaseMonthly() async -> AIProSubscriptionStatus {
        let product: Product

        if let monthlyProduct {
            product = monthlyProduct
        } else {
            let refreshedStatus = await refreshStatus()
            guard let loadedProduct = monthlyProduct else {
                status = refreshedStatus
                return status
            }
            product = loadedProduct
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    status = .failed(AppText.aiProTransactionUnverified)
                    return status
                }
                await transaction.finish()
                return await refreshStatus()
            case .userCancelled:
                return status
            case .pending:
                status = .failed(AppText.aiProTransactionPending)
                return status
            @unknown default:
                status = .failed(AppText.aiProTransactionUnknown)
                return status
            }
        } catch {
            status = .failed(error.localizedDescription)
            return status
        }
    }

    func restorePurchases() async -> AIProSubscriptionStatus {
        do {
            try await AppStore.sync()
            return await refreshStatus()
        } catch {
            status = .failed(error.localizedDescription)
            return status
        }
    }
}

private extension AIProSubscriptionService {
    func makeProductViewModel(from product: Product) -> AIProSubscriptionProduct {
        AIProSubscriptionProduct(
            id: product.id,
            displayName: product.displayName,
            displayPrice: product.displayPrice,
            description: product.description
        )
    }

    func hasVerifiedEntitlement(for productID: String) async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            if transaction.productID == productID {
                return true
            }
        }

        return false
    }
}
