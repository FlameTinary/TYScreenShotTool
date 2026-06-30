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

    private(set) var status: AIProSubscriptionStatus

    private init() {
        self.backendClient = AIProBackendClient()
        self.status = AIProSubscriptionStatus.cachedStatus() ?? .notLoaded
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

    func clearCachedStatus() {
        monthlyProduct = nil
        status = .notLoaded
        AIProSubscriptionStatus.clearCachedStatus()
    }

    func refreshStatus() async -> AIProSubscriptionStatus {
        let cachedProduct = status.product
        status = .loading
        var productLoadError: Error?
        var viewModel: AIProSubscriptionProduct?

        do {
            let products = try await Product.products(for: [AIProSubscriptionProductID.monthly])
            if let product = products.first {
                monthlyProduct = product
                viewModel = makeProductViewModel(from: product)
            } else {
                monthlyProduct = nil
            }
        } catch {
            monthlyProduct = nil
            productLoadError = error
        }

        do {
            let subscription = try await backendClient.fetchSubscriptionStatus()
            status = AIProSubscriptionStatus.statusAfterBackendRefresh(
                loadedProduct: viewModel,
                cachedProduct: cachedProduct,
                backendStatus: subscription.status,
                backendProductID: subscription.product_id
            )
            status.saveCachedStatus()
        } catch let error as AIProBackendError {
            switch error {
            case .regionUnavailable:
                status = .regionUnavailable
                AIProSubscriptionStatus.clearCachedStatus()
            default:
                status = .failed(error.localizedDescription)
            }
        } catch {
            status = .failed(productLoadError?.localizedDescription ?? error.localizedDescription)
        }

        return status
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

                print("[AI Pro Subscription] Purchase transaction received:")
                print("  - id: \(transaction.id)")
                print("  - productID: \(transaction.productID)")
                print("  - purchaseDate: \(transaction.purchaseDate)")
                print("  - appAccountToken: \(transaction.appAccountToken?.uuidString ?? "nil")")
                print("  - jwsRepresentation: \(verification.jwsRepresentation.prefix(100))...")

                let backendConfirmed = await reportVerificationToBackend(verification)
                if backendConfirmed {
                    await transaction.finish()
                }
                status = AIProSubscriptionStatus.statusAfterVerifiedPurchase(
                    product: makeProductViewModel(from: product),
                    backendConfirmed: backendConfirmed
                )
                status.saveCachedStatus()
                return status

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
    /// 恢复订阅
    /// - Returns: 订阅状态
    func restorePurchases() async -> AIProSubscriptionStatus {
        do {
            status = .loading
            try await AppStore.sync()

            var confirmedStatus: AIProSubscriptionStatus?

            // 恢复后，将当前有效交易上报后端
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result,
                      transaction.productID == AIProSubscriptionProductID.monthly else {
                    continue
                }
                
                print("[AI Pro Subscription] Restored transaction for \(transaction.productID):")
                print("  - id: \(transaction.id)")
                print("  - productID: \(transaction.productID)")
                print("  - purchaseDate: \(transaction.purchaseDate)")
                print("  - appAccountToken: \(transaction.appAccountToken?.uuidString ?? "nil")")
                print("  - jwsRepresentation: \(result.jwsRepresentation.prefix(100))...")

                if await reportVerificationToBackend(result) {
                    let product = await monthlyProductViewModel(fallbackID: transaction.productID)
                    let restoredStatus = AIProSubscriptionStatus.subscribed(product)
                    status = restoredStatus
                    status.saveCachedStatus()
                    confirmedStatus = restoredStatus
                    await transaction.finish()
                }
            }

            let refreshedStatus = await refreshStatus()
            if refreshedStatus.isSubscribed {
                return refreshedStatus
            }
            if case .failed = refreshedStatus, let confirmedStatus {
                status = confirmedStatus
                status.saveCachedStatus()
                return status
            }
            return refreshedStatus
        } catch {
            print("[AI Pro Subscription] Restore purchases failed: \(error.localizedDescription)")
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

    func monthlyProductViewModel(fallbackID: String) async -> AIProSubscriptionProduct {
        if let monthlyProduct {
            return makeProductViewModel(from: monthlyProduct)
        }
        if let cachedProduct = status.product {
            return cachedProduct
        }
        if let product = try? await Product.products(for: [AIProSubscriptionProductID.monthly]).first {
            monthlyProduct = product
            return makeProductViewModel(from: product)
        }
        return AIProSubscriptionProduct(
            id: fallbackID,
            displayName: "AI Pro Monthly",
            displayPrice: "",
            description: "AI Pro Monthly"
        )
    }

    /// 将 StoreKit 交易验证结果中的 signedTransaction (JWS) 上报后端
    func reportVerificationToBackend(_ verification: VerificationResult<Transaction>) async -> Bool {
        let jws = verification.jwsRepresentation
        print("[AI Pro Subscription] Reporting StoreKit verification to backend")
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
