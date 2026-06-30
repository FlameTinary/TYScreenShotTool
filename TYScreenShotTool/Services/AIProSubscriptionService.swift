import Foundation
import StoreKit

/// AI Pro 订阅服务
///
/// 封装完整的 StoreKit 2 订阅生命周期管理：
/// 1. 商品加载（通过 Product.products() 获取订阅商品信息）
/// 2. 购买流程（product.purchase() + appAccountToken 关联用户）
/// 3. 恢复购买（AppStore.sync() + Transaction.currentEntitlements）
/// 4. 交易更新监听（Transaction.updates 异步序列）
/// 5. 后端验证（将 signedTransaction JWS 发送到 Cloudflare Worker）
///
/// **核心设计要点**：
/// - 使用 appAccountToken 关联 Apple 交易与后端用户（userID 作为 token）
/// - 购买/恢复成功后必须上报后端验证，后端返回 active 状态才算真正订阅成功
/// - 订阅状态缓存机制：使用 UserDefaults 缓存，避免频繁网络请求
/// - 区域策略：中国大陆用户无法购买（通过 AppRegionPolicyProvider 判断）
/// - 线程安全：使用 @MainActor 保证状态更新在主线程
@MainActor
final class AIProSubscriptionService {
    static let shared = AIProSubscriptionService()

    /// 当前加载的月度订阅商品（从 StoreKit 获取）
    private var monthlyProduct: Product?
    /// 交易更新监听任务（监听 Transaction.updates 异步序列）
    private var transactionUpdatesTask: Task<Void, Never>?
    /// 后端 API 客户端，用于验证订阅和查询状态
    private let backendClient: AIProBackendClient

    /// 当前订阅状态（对外只读）
    private(set) var status: AIProSubscriptionStatus

    private init() {
        self.backendClient = AIProBackendClient()
        // 优先从缓存恢复订阅状态，避免启动时重复请求
        self.status = AIProSubscriptionStatus.cachedStatus() ?? .notLoaded
    }

    deinit {
        // 取消交易监听任务，防止内存泄漏
        transactionUpdatesTask?.cancel()
    }

    /// 启动交易更新监听
    ///
    /// 在 App 启动时调用，监听 StoreKit 的交易更新事件（如自动续期、退款等）。
    /// 使用 `for await` 异步序列监听 `Transaction.updates`，处理以下场景：
    /// - 订阅自动续期成功
    /// - 用户在 App Store 中取消订阅
    /// - 订阅退款
    /// - 家庭共享订阅变更
    ///
    /// **注意**：此方法只应调用一次，多次调用会被忽略（通过 transactionUpdatesTask 判空）。
    func startTransactionListener() {
        guard transactionUpdatesTask == nil else {
            return
        }

        transactionUpdatesTask = Task { [weak self] in
            // 异步监听交易更新，这个循环会持续到 Task 被取消
            for await result in Transaction.updates {
                guard let self else {
                    return
                }
                // 验证交易签名后，上报后端验证
                if case .verified(let transaction) = result {
                    if await self.reportVerificationToBackend(result) {
                        await transaction.finish()
                    }
                }
                // 无论验证结果如何，都刷新订阅状态
                _ = await self.refreshStatus()
            }
        }
    }

    /// 清除订阅状态缓存
    ///
    /// 退出登录时调用，清除本地缓存的订阅状态和商品信息。
    func clearCachedStatus() {
        monthlyProduct = nil
        status = .notLoaded
        AIProSubscriptionStatus.clearCachedStatus()
    }

    /// 刷新订阅状态
    ///
    /// 完整流程：
    /// 1. 从 StoreKit 加载订阅商品信息
    /// 2. 调用后端 API 查询当前订阅状态
    /// 3. 根据后端返回和商品信息计算最终状态
    /// 4. 缓存状态到 UserDefaults
    ///
    /// **区域策略**：如果后端返回 regionUnavailable（HTTP 403），设置状态为 regionUnavailable。
    /// **缓存策略**：成功获取状态后缓存，失败时使用缓存的商品信息。
    ///
    /// - Returns: 最新的订阅状态
    func refreshStatus() async -> AIProSubscriptionStatus {
        // 保存当前缓存的商品信息，用于后端请求失败时的回退
        let cachedProduct = status.product
        // 设置加载状态，UI 可以显示加载中
        status = .loading
        var productLoadError: Error?
        var viewModel: AIProSubscriptionProduct?

        // 步骤1：从 StoreKit 加载订阅商品信息
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

        // 步骤2：调用后端 API 查询订阅状态
        do {
            let subscription = try await backendClient.fetchSubscriptionStatus()
            // 根据后端返回计算最终状态
            status = AIProSubscriptionStatus.statusAfterBackendRefresh(
                loadedProduct: viewModel,
                cachedProduct: cachedProduct,
                backendStatus: subscription.status,
                backendProductID: subscription.product_id
            )
            // 缓存状态到 UserDefaults
            status.saveCachedStatus()
        } catch let error as AIProBackendError {
            // 处理特定的后端错误
            switch error {
            case .regionUnavailable:
                // 区域不可用（中国大陆），清除缓存
                status = .regionUnavailable
                AIProSubscriptionStatus.clearCachedStatus()
            default:
                status = .failed(error.localizedDescription)
            }
        } catch {
            // 处理其他错误（网络错误等）
            status = .failed(productLoadError?.localizedDescription ?? error.localizedDescription)
        }

        return status
    }

    /// 购买月度订阅
    ///
    /// 完整购买流程：
    /// 1. 确保商品信息已加载（如果未加载，先调用 refreshStatus）
    /// 2. 检查用户是否已登录（需要 userID 作为 appAccountToken）
    /// 3. 调用 StoreKit 的 product.purchase()，传入 appAccountToken 关联用户
    /// 4. 处理购买结果（成功/取消/待处理）
    /// 5. 验证成功后，将 signedTransaction JWS 上报后端验证
    /// 6. 根据后端验证结果更新订阅状态
    ///
    /// **appAccountToken 的作用**：
    /// - 将 Apple 交易与后端用户关联，用于恢复购买时匹配用户
    /// - 使用用户的 UUID 作为 token 值
    ///
    /// **关键约束**：
    /// - 必须先登录才能购买（否则无法生成 appAccountToken）
    /// - 购买成功后必须上报后端验证，后端返回 active 才算真正成功
    /// - 交易签名验证失败时，状态为 unverified
    ///
    /// - Returns: 购买后的订阅状态
    func purchaseMonthly() async -> AIProSubscriptionStatus {
        // 步骤1：确保订阅商品已加载
        let product: Product
        if let monthlyProduct {
            product = monthlyProduct
        } else {
            // 商品未加载，先刷新状态
            let refreshedStatus = await refreshStatus()
            guard let loadedProduct = monthlyProduct else {
                status = refreshedStatus
                return status
            }
            product = loadedProduct
        }

        do {
            // 步骤2：检查登录状态，确保有用户 ID 作为 appAccountToken
            guard let userID = AIProSessionManager.shared.currentUserID,
                  let appAccountToken = UUID(uuidString: userID) else {
                status = .failed(AppText.aiProLoginRequiredForPurchase)
                return status
            }

            // 步骤3：调用 StoreKit 发起购买
            // appAccountToken 将交易与用户关联，恢复购买时后端用此匹配
            TYLogger.info("Starting StoreKit purchase for \(product.id)", tag: "AI Pro Subscription")
            let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
            TYLogger.info("StoreKit purchase returned: \(result)", tag: "AI Pro Subscription")

            // 步骤4：处理购买结果
            switch result {
            case .success(let verification):
                // 验证交易签名
                guard case .verified(let transaction) = verification else {
                    status = .failed(AppText.aiProTransactionUnverified)
                    return status
                }

                // 打印交易信息用于调试
                TYLogger.debug("Purchase transaction received:", tag: "AI Pro Subscription")
                TYLogger.debug("  - id: \(transaction.id)", tag: "AI Pro Subscription")
                TYLogger.debug("  - productID: \(transaction.productID)", tag: "AI Pro Subscription")
                TYLogger.debug("  - purchaseDate: \(transaction.purchaseDate)", tag: "AI Pro Subscription")
                TYLogger.debug("  - appAccountToken: \(transaction.appAccountToken?.uuidString ?? "nil")", tag: "AI Pro Subscription")
                TYLogger.debug("  - jwsRepresentation: \(verification.jwsRepresentation.prefix(100))...", tag: "AI Pro Subscription")

                // 步骤5：上报后端验证
                let backendConfirmed = await reportVerificationToBackend(verification)
                if backendConfirmed {
                    // 后端验证成功，完成交易
                    await transaction.finish()
                }
                // 步骤6：更新订阅状态
                status = AIProSubscriptionStatus.statusAfterVerifiedPurchase(
                    product: makeProductViewModel(from: product),
                    backendConfirmed: backendConfirmed
                )
                status.saveCachedStatus()
                return status

            case .userCancelled:
                // 用户取消购买
                TYLogger.info("StoreKit purchase cancelled by user", tag: "AI Pro Subscription")
                return status
            case .pending:
                // 交易待处理（如需要家长批准）
                status = .failed(AppText.aiProTransactionPending)
                return status
            @unknown default:
                // 处理未来可能新增的结果类型
                status = .failed(AppText.aiProTransactionUnknown)
                return status
            }
        } catch {
            // 处理购买过程中的错误（如 StoreKit Agent 连接失败）
            status = .failed(error.localizedDescription)
            return status
        }
    }
    /// 恢复订阅
    ///
    /// 恢复购买流程用于以下场景：
    /// - 用户更换设备后恢复订阅
    /// - 用户重新安装 App 后恢复订阅
    /// - 用户登录新账号后恢复订阅
    ///
    /// 完整流程：
    /// 1. 调用 AppStore.sync() 同步本地交易记录与 App Store
    /// 2. 遍历 Transaction.currentEntitlements 获取当前有效的订阅交易
    /// 3. 验证交易签名并过滤出正确的商品 ID
    /// 4. 将有效的 signedTransaction JWS 上报后端验证
    /// 5. 后端验证成功后更新订阅状态并完成交易
    /// 6. 调用 refreshStatus() 刷新最终状态
    ///
    /// **关键机制**：
    /// - appAccountToken 用于匹配后端用户（购买时设置，恢复时 Apple 返回）
    /// - Transaction.currentEntitlements 只返回当前有效的订阅交易
    /// - 即使后端验证失败，也会尝试刷新状态（可能有其他订阅来源）
    ///
    /// **注意**：如果没有找到有效的订阅交易，循环不会执行，直接刷新状态。
    ///
    /// - Returns: 恢复后的订阅状态
    func restorePurchases() async -> AIProSubscriptionStatus {
        do {
            // 步骤1：设置加载状态
            status = .loading
            // 步骤2：同步本地交易记录与 App Store
            try await AppStore.sync()

            // 保存后端验证成功的状态（用于后端刷新失败时的回退）
            var confirmedStatus: AIProSubscriptionStatus?

            // 步骤3：遍历当前有效的订阅交易
            // Transaction.currentEntitlements 返回用户当前拥有的所有有效订阅
            for await result in Transaction.currentEntitlements {
                // 验证交易签名并过滤出正确的商品 ID
                guard case .verified(let transaction) = result,
                      transaction.productID == AIProSubscriptionProductID.monthly else {
                    continue
                }
                
                // 打印恢复的交易信息用于调试
                TYLogger.debug("Restored transaction for \(transaction.productID):", tag: "AI Pro Subscription")
                TYLogger.debug("  - id: \(transaction.id)", tag: "AI Pro Subscription")
                TYLogger.debug("  - productID: \(transaction.productID)", tag: "AI Pro Subscription")
                TYLogger.debug("  - purchaseDate: \(transaction.purchaseDate)", tag: "AI Pro Subscription")
                TYLogger.debug("  - appAccountToken: \(transaction.appAccountToken?.uuidString ?? "nil")", tag: "AI Pro Subscription")
                TYLogger.debug("  - jwsRepresentation: \(result.jwsRepresentation.prefix(100))...", tag: "AI Pro Subscription")

                // 步骤4：上报后端验证
                if await reportVerificationToBackend(result) {
                    // 后端验证成功
                    let product = await monthlyProductViewModel(fallbackID: transaction.productID)
                    let restoredStatus = AIProSubscriptionStatus.subscribed(product)
                    status = restoredStatus
                    status.saveCachedStatus()
                    confirmedStatus = restoredStatus
                    // 完成交易
                    await transaction.finish()
                }
            }

            // 步骤5：刷新最终状态
            let refreshedStatus = await refreshStatus()
            
            // 策略：如果后端刷新显示已订阅，返回刷新后的状态
            if refreshedStatus.isSubscribed {
                return refreshedStatus
            }
            
            // 策略：如果后端刷新失败，但本地验证成功，使用本地状态
            if case .failed = refreshedStatus, let confirmedStatus {
                status = confirmedStatus
                status.saveCachedStatus()
                return status
            }
            
            // 其他情况返回刷新后的状态
            return refreshedStatus
        } catch {
            // 处理恢复过程中的错误（如 AppStore.sync() 失败）
            TYLogger.error("Restore purchases failed", tag: "AI Pro Subscription", error: error)
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
        TYLogger.info("Reporting StoreKit verification to backend", tag: "AI Pro Subscription")
        do {
            let response = try await backendClient.verifySubscription(signedTransaction: jws)
            TYLogger.info("Backend verify success: \(response.status)", tag: "AI Pro Subscription")
            return response.status == "active" || response.status == "grace_period"
        } catch {
            TYLogger.error("Backend verify failed", tag: "AI Pro Subscription", error: error)
            return false
        }
    }
}
