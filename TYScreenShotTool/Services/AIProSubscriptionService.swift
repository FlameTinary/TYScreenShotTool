import Foundation
import StoreKit

/// AI Pro 订阅服务
///
/// 封装 StoreKit 2 商品加载、购买、恢复购买和交易更新监听。
/// 购买成功后，将 signedTransaction 上报后端验证（Feature 53.8）。
@MainActor
final class AIProSubscriptionService {
    static let shared = AIProSubscriptionService()

    private var monthlyProduct: Product?
    private var transactionUpdatesTask: Task<Void, Never>?
    private let backendClient: AIProBackendClient

    private(set) var status: AIProSubscriptionStatus = .notLoaded

    private init() {
        self.backendClient = AIProBackendClient()
    }

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
                    if await self.reportVerificationToBackend(result) {
                        await transaction.finish()
                    }
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

            do {
                let subscription = try await backendClient.fetchSubscriptionStatus()
                guard subscription.product_id == nil || subscription.product_id == viewModel.id else {
                    status = .unsubscribed(viewModel)
                    return status
                }

                status = subscription.status == "active" || subscription.status == "grace_period"
                    ? .subscribed(viewModel)
                    : .unsubscribed(viewModel)
            } catch let error as AIProBackendError {
                switch error {
                case .regionUnavailable:
                    status = .regionUnavailable
                default:
                    status = .failed(error.localizedDescription)
                }
            }
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
            guard let userID = AIProSessionManager.shared.currentUserID,
                  let appAccountToken = UUID(uuidString: userID) else {
                status = .failed(AppText.aiProLoginRequiredForPurchase)
                return status
            }

            print("[AI Pro Subscription] Starting StoreKit purchase for \(product.id)")
            let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
            print("[AI Pro Subscription] StoreKit purchase returned: \(result)")

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    status = .failed(AppText.aiProTransactionUnverified)
                    return status
                }

                guard await reportVerificationToBackend(verification) else {
                    status = .failed(AppText.aiProBackendVerificationFailed)
                    return status
                }

                await transaction.finish()
                return await refreshStatus()

            case .userCancelled:
                print("[AI Pro Subscription] StoreKit purchase cancelled by user")
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

            // 恢复后，将当前有效交易上报后端
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else {
                    continue
                }
                if await reportVerificationToBackend(result) {
                    await transaction.finish()
                }
            }

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

    /// 将 StoreKit 交易验证结果中的 signedTransaction (JWS) 上报后端
    func reportVerificationToBackend(_ verification: VerificationResult<Transaction>) async -> Bool {
        let jws = verification.jwsRepresentation

        do {
            let response = try await backendClient.verifySubscription(signedTransaction: jws)
            print("[AI Pro Subscription] Backend verify success: \(response.status)")
            return response.status == "active" || response.status == "grace_period"
        } catch {
            print("[AI Pro Subscription] Backend verify failed: \(error.localizedDescription)")
            return false
        }
    }
}
