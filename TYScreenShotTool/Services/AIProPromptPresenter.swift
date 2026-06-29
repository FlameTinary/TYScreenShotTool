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
    static func show(
        from view: NSView?,
        subscriptionService: AIProSubscriptionService? = nil
    ) async {
        let subscriptionService = subscriptionService ?? .shared

        // 1. 区域策略
        guard AIAvailabilityService().isSubscriptionAllowed else {
            await showPrompt(
                from: view,
                content: AIProSubscriptionPromptContent(status: .regionUnavailable),
                subscriptionService: subscriptionService
            )
            return
        }

        // 2. 首次使用同意提示（Feature 53.10）
        guard await showConsentIfNeeded(from: view) else {
            return
        }

        // 3. Apple 登录检查（Feature 53.7）
        guard await showLoginIfNeeded(from: view) else {
            return
        }

        // 4. 加载订阅并展示
        subscriptionService.startTransactionListener()
        let status = await subscriptionService.refreshStatus()
        await showPrompt(
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

        // 注意：NSAlert 使用 addButton 顺序是 从右到左
        // 按钮1（最右边）："查看隐私政策"
        // 按钮2（中间）："取消"
        // 按钮3（最左边）："同意并继续"
        let privacyButton = alert.addButton(withTitle: AppText.aiFirstUseConsentPrivacyButton)
        let cancelButton = alert.addButton(withTitle: AppText.cancelButton)
        let agreeButton = alert.addButton(withTitle: AppText.aiFirstUseConsentAgreeButton)

        // 设置按钮标识
        agreeButton.tag = 1
        cancelButton.tag = 2
        privacyButton.tag = 3

        let response: NSApplication.ModalResponse
        if let window = view?.window {
            response = await alert.beginSheetModal(for: window)
        } else {
            response = alert.runModal()
        }

        // 用户点击"同意并继续"
        if response.rawValue == 1000 { // 第一个按钮（最左边）
            UserDefaults.standard.set(true, forKey: AppSettings.aiFirstUseConsentKey)
            return true
        }

        // 用户点击"查看隐私政策"（第三个按钮，最右边）
        if response.rawValue == 1002 {
            if let url = URL(string: "https://tshot.app/privacy") {
                NSWorkspace.shared.open(url)
            }
            // 不记录同意，让用户再选一次
            return await showConsentIfNeeded(from: view)
        }

        // 用户取消
        return false
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

        let cancelButton = alert.addButton(withTitle: AppText.cancelButton)
        let loginButton = alert.addButton(withTitle: AppText.aiProLoginButton)

        loginButton.tag = 1
        cancelButton.tag = 2

        let response: NSApplication.ModalResponse
        if let window = view?.window {
            response = await alert.beginSheetModal(for: window)
        } else {
            response = alert.runModal()
        }

        guard response.rawValue == 1000 else {
            return false
        }

        // 发起 Apple 登录
        do {
            _ = try await AIProAuthService.shared.signIn()
            return true
        } catch {
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
    ) async {
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
        await handle(action, from: view, subscriptionService: subscriptionService)
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
    ) async {
        let nextStatus: AIProSubscriptionStatus

        switch action {
        case .subscribe:
            nextStatus = await subscriptionService.purchaseMonthly()
        case .restore:
            nextStatus = await subscriptionService.restorePurchases()
        case .dismiss:
            return
        }

        await showPrompt(
            from: view,
            content: AIProSubscriptionPromptContent(status: nextStatus),
            subscriptionService: subscriptionService
        )
    }
}
