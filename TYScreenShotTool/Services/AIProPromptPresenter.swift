import AppKit

/// AI Pro 弹窗流程编排器
///
/// 负责编排 AI Pro 功能使用前的完整验证流程，按顺序执行以下检查：
///
/// **完整流程**：
/// 1. **区域策略检查**（Feature 53.9）- 中国大陆用户无法使用 AI Pro
/// 2. **首次使用同意提示**（Feature 53.10）- 用户首次使用时展示隐私政策同意弹窗
/// 3. **Apple 登录检查**（Feature 53.7）- 未登录用户展示登录提示
/// 4. **后端订阅状态检查**（Feature 53.8）- 查询后端确认订阅状态
/// 5. **订阅弹窗展示** - 根据状态展示购买/恢复/错误弹窗
///
/// **设计要点**：
/// - 使用 `isPresenting` 标志防止重复弹窗
/// - 使用 `@MainActor` 保证 UI 操作在主线程
/// - 所有弹窗通过 `NSAlert` 展示，支持 Sheet 模式（有父窗口时）
/// - 流程可中断：用户取消任意步骤都会终止后续流程
@MainActor
enum AIProPromptPresenter {
    /// 弹窗展示状态标志，防止重复弹窗
    private static var isPresenting = false

    /// 获取当前 AI Pro 访问状态
    ///
    /// 根据区域策略、登录状态和订阅状态计算当前访问状态。
    /// 如果已登录且订阅状态需要刷新，会后台异步刷新。
    ///
    /// - Returns: 当前访问状态（ready/needsLogin/needsSubscription/regionBlocked 等）
    static func currentAccessState() async -> AIProAccessState {
        let subscriptionService = AIProSubscriptionService.shared
        // 根据区域策略、登录状态和订阅状态解析当前访问状态
        let state = AIProAccessState.resolve(
            isSubscriptionAllowed: AIAvailabilityService().isSubscriptionAllowed,
            isSignedIn: AIProSessionManager.shared.isSignedIn,
            subscriptionStatus: subscriptionService.status
        )

        // 如果已登录且订阅状态需要网络刷新，后台异步刷新（不阻塞当前调用）
        if AIProSessionManager.shared.isSignedIn,
           subscriptionService.status.needsNetworkRefresh {
            Task {
                _ = await subscriptionService.refreshStatus()
            }
        }

        return state
    }

    /// 判断是否可以直接展示 AI 功能菜单
    ///
    /// 检查当前访问状态是否为 ready，即用户已登录且有有效订阅。
    ///
    /// - Returns: true 表示可以展示 AI 功能菜单
    static func isReadyForAIMenu() async -> Bool {
        await currentAccessState() == .ready
    }

    /// 展示登录引导流程（仅执行区域策略和登录检查，不展示订阅弹窗）
    ///
    /// **流程**：
    /// 1. 区域策略检查
    /// 2. 首次使用同意提示（如需要）
    /// 3. Apple 登录（如需要）
    ///
    /// - Parameter view: 父视图，用于 Sheet 模式展示弹窗
    static func showLoginOnboarding(from view: NSView? = nil) async {
        guard beginPresenting() else {
            // 已有弹窗正在展示，忽略本次请求
            return
        }
        defer { endPresenting() }

        // 步骤1：区域策略检查
        guard AIAvailabilityService().isSubscriptionAllowed else {
            await showRegionUnavailable(from: view)
            return
        }

        // 步骤2：首次使用同意提示
        guard await showConsentIfNeeded(from: view) else {
            print("[AI Pro Prompt] user cancelled first-use consent")
            return
        }

        // 步骤3：Apple 登录（如需要）
        _ = await showLoginIfNeeded(from: view)
    }

    /// 展示完整订阅引导流程（包含所有检查步骤）
    ///
    /// 执行完整的访问验证流程：区域策略 → 同意提示 → 登录 → 订阅状态 → 弹窗
    ///
    /// - Parameter view: 父视图，用于 Sheet 模式展示弹窗
    static func showSubscriptionOnboarding(from view: NSView? = nil) async {
        guard beginPresenting() else {
            return
        }
        defer { endPresenting() }

        _ = await showGatedFlow(from: view, subscriptionService: .shared)
    }

    /// 展示区域不可用弹窗
    ///
    /// 当用户在中国大陆区域时调用，展示提示信息。
    ///
    /// - Parameter view: 父视图，用于 Sheet 模式展示弹窗
    static func showRegionUnavailable(from view: NSView? = nil) async {
        let subscriptionService = AIProSubscriptionService.shared
        _ = await showPrompt(
            from: view,
            content: AIProSubscriptionPromptContent(status: .regionUnavailable),
            subscriptionService: subscriptionService
        )
    }

    /// 展示完整验证流程（推荐入口）
    ///
    /// 执行完整的访问验证流程，返回最终是否获得访问权限。
    ///
    /// - Parameters:
    ///   - view: 父视图，用于 Sheet 模式展示弹窗
    ///   - subscriptionService: 订阅服务实例（默认使用共享实例）
    /// - Returns: true 表示用户已获得访问权限（已登录且有有效订阅）
    static func show(
        from view: NSView?,
        subscriptionService: AIProSubscriptionService? = nil
    ) async -> Bool {
        guard beginPresenting() else {
            return false
        }
        defer { endPresenting() }

        return await showGatedFlow(from: view, subscriptionService: subscriptionService ?? .shared)
    }
}

private extension AIProPromptPresenter {
    static func showGatedFlow(
        from view: NSView?,
        subscriptionService: AIProSubscriptionService
    ) async -> Bool {

        // 1. 区域策略
        guard AIAvailabilityService().isSubscriptionAllowed else {
            print("[AI Pro Prompt] blocked by region policy")
            _ = await showPrompt(
                from: view,
                content: AIProSubscriptionPromptContent(status: .regionUnavailable),
                subscriptionService: subscriptionService
            )
            return false
        }

        // 2. 首次使用同意提示（Feature 53.10）
        guard await showConsentIfNeeded(from: view) else {
            print("[AI Pro Prompt] user cancelled first-use consent")
            return false
        }
        print("[AI Pro Prompt] first-use consent accepted")

        // 3. Apple 登录检查（Feature 53.7）
        guard await showLoginIfNeeded(from: view) else {
            print("[AI Pro Prompt] user cancelled or failed login")
            return false
        }
        print("[AI Pro Prompt] login check passed")

        // 4. 加载订阅并展示
        subscriptionService.startTransactionListener()
        let status = await subscriptionService.refreshStatus()
        print("[AI Pro Prompt] subscription status: \(status)")
        guard status.isSubscribed == false else {
            return true
        }

        return await showPrompt(
            from: view,
            content: AIProSubscriptionPromptContent(status: status),
            subscriptionService: subscriptionService
        )
    }
}

private extension AIProPromptPresenter {
    static func beginPresenting() -> Bool {
        guard isPresenting == false else {
            print("[AI Pro Prompt] ignored duplicate prompt request")
            return false
        }
        isPresenting = true
        return true
    }

    static func endPresenting() {
        isPresenting = false
    }
}

// MARK: - 同意弹窗

private extension AIProPromptPresenter {
    /// 检查首次使用同意，未同意则展示弹窗
    /// - Returns: true 表示已同意（可以继续），false 表示用户关闭
    static func showConsentIfNeeded(from view: NSView?) async -> Bool {
        guard !UserDefaults.standard.bool(forKey: AppSettings.aiFirstUseConsentKey) else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = AppText.aiFirstUseConsentTitle
        alert.informativeText = AppText.aiFirstUseConsentMessage
        alert.alertStyle = .informational

        alert.addButton(withTitle: AppText.aiFirstUseConsentAgreeButton)
        alert.addButton(withTitle: AppText.cancelButton)

        let response: NSApplication.ModalResponse
        if let window = view?.window {
            response = await alert.beginSheetModal(for: window)
        } else {
            response = alert.runModal()
        }

        switch response {
        case .alertFirstButtonReturn:
            UserDefaults.standard.set(true, forKey: AppSettings.aiFirstUseConsentKey)
            print("[AI Pro Prompt] consent alert returned first button")
            return true

        default:
            print("[AI Pro Prompt] consent alert cancelled: \(response.rawValue)")
            return false
        }
    }
}

// MARK: - 登录弹窗

private extension AIProPromptPresenter {
    /// 检查登录状态，未登录则发起 Sign in with Apple
    /// - Returns: true 表示已登录或登录成功，false 表示用户取消
    static func showLoginIfNeeded(from view: NSView?) async -> Bool {
        guard !AIProSessionManager.shared.isSignedIn else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = AppText.aiProLoginPromptTitle
        alert.informativeText = AppText.aiProLoginPromptMessage
        alert.alertStyle = .informational

        alert.addButton(withTitle: AppText.aiProLoginButton)
        alert.addButton(withTitle: AppText.cancelButton)

        let response: NSApplication.ModalResponse
        if let window = view?.window {
            response = await alert.beginSheetModal(for: window)
        } else {
            response = alert.runModal()
        }

        guard response == .alertFirstButtonReturn else {
            print("[AI Pro Prompt] login alert cancelled: \(response.rawValue)")
            return false
        }

        do {
            print("[AI Pro Prompt] starting Sign in with Apple")
            _ = try await AIProAuthService.shared.signIn()
            _ = await AIProSubscriptionService.shared.refreshStatus()
            return true
        } catch {
            print("[AI Pro Prompt] Sign in with Apple failed: \(error.localizedDescription)")
            // 显示错误并给用户重试机会
            let errorAlert = NSAlert()
            errorAlert.messageText = AppText.aiProLoginFailedTitle
            errorAlert.informativeText = error.localizedDescription
            errorAlert.alertStyle = .warning
            errorAlert.addButton(withTitle: AppText.cancelButton)
            errorAlert.addButton(withTitle: AppText.aiProRetryLoginButton)

            let errorResponse: NSApplication.ModalResponse
            if let window = view?.window {
                errorResponse = await errorAlert.beginSheetModal(for: window)
            } else {
                errorResponse = errorAlert.runModal()
            }

            if errorResponse.rawValue == 1000 {
                return false
            }

            // 重试
            return await showLoginIfNeeded(from: view)
        }
    }
}

// MARK: - 订阅弹窗（同现有逻辑）

private extension AIProPromptPresenter {
    static func showPrompt(
        from view: NSView?,
        content: AIProSubscriptionPromptContent,
        subscriptionService: AIProSubscriptionService
    ) async -> Bool {
        let alert = NSAlert()
        alert.messageText = content.title
        alert.informativeText = content.message
        alert.alertStyle = .informational
        alert.addButton(withTitle: content.primaryButtonTitle)

        if let secondaryButtonTitle = content.secondaryButtonTitle {
            alert.addButton(withTitle: secondaryButtonTitle)
        }

        if let cancelButtonTitle = content.cancelButtonTitle {
            alert.addButton(withTitle: cancelButtonTitle)
        }

        let response: NSApplication.ModalResponse
        if let window = view?.window {
            response = await alert.beginSheetModal(for: window)
        } else {
            response = alert.runModal()
        }

        let action = action(for: response, content: content)
        return await handle(action, from: view, subscriptionService: subscriptionService)
    }

    static func action(
        for response: NSApplication.ModalResponse,
        content: AIProSubscriptionPromptContent
    ) -> AIProSubscriptionPromptAction {
        switch response {
        case .alertFirstButtonReturn:
            return content.primaryAction
        case .alertSecondButtonReturn:
            return content.secondaryAction ?? .dismiss
        default:
            return .dismiss
        }
    }

    /// 处理订阅按钮操作，购买后上报后端
    static func handle(
        _ action: AIProSubscriptionPromptAction,
        from view: NSView?,
        subscriptionService: AIProSubscriptionService
    ) async -> Bool {
        let nextStatus: AIProSubscriptionStatus

        switch action {
        case .subscribe:
            nextStatus = await subscriptionService.purchaseMonthly()
        case .restore:
            nextStatus = await subscriptionService.restorePurchases()
        case .dismiss:
            return false
        }

        if case .failed(let message) = nextStatus {
            print("[AI Pro Prompt] subscription action failed: \(message)")
        }
        return nextStatus.isSubscribed
    }
}
