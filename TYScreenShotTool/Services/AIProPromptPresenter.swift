import AppKit

/// AI Pro 弹窗流程编排
///
/// 按顺序执行：
/// 1. 首次使用同意提示（Feature 53.10）
/// 2. Apple 登录检查（Feature 53.7）
/// 3. 后端订阅状态检查（Feature 53.8）
/// 4. 展示订阅商品 / 购买 / 恢复弹窗
@MainActor
enum AIProPromptPresenter {
    private static var isPresenting = false

    static func isReadyForAIMenu() async -> Bool {
        guard AIAvailabilityService().isSubscriptionAllowed else {
            return false
        }
        guard UserDefaults.standard.bool(forKey: AppSettings.aiFirstUseConsentKey) else {
            return false
        }
        guard AIProSessionManager.shared.isSignedIn else {
            return false
        }

        do {
            let subscription = try await AIProBackendClient().fetchSubscriptionStatus()
            return subscription.status == "active" || subscription.status == "grace_period"
        } catch {
            print("[AI Pro Prompt] preflight subscription check failed: \(error.localizedDescription)")
            return false
        }
    }

    static func show(
        from view: NSView?,
        subscriptionService: AIProSubscriptionService? = nil
    ) async -> Bool {
        guard isPresenting == false else {
            print("[AI Pro Prompt] ignored duplicate prompt request")
            return false
        }
        isPresenting = true
        defer {
            isPresenting = false
        }

        let subscriptionService = subscriptionService ?? .shared

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

        // 发起 Apple 登录
        do {
            print("[AI Pro Prompt] starting Sign in with Apple")
            _ = try await AIProAuthService.shared.signIn()
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
