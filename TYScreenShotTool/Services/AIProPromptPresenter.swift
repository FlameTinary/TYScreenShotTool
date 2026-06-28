import AppKit

@MainActor
enum AIProPromptPresenter {
    static func show(
        from view: NSView?,
        subscriptionService: AIProSubscriptionService? = nil
    ) async {
        let subscriptionService = subscriptionService ?? .shared

        guard AIAvailabilityService().isSubscriptionAllowed else {
            await showPrompt(
                from: view,
                content: AIProSubscriptionPromptContent(status: .regionUnavailable),
                subscriptionService: subscriptionService
            )
            return
        }

        subscriptionService.startTransactionListener()
        let status = await subscriptionService.refreshStatus()
        await showPrompt(
            from: view,
            content: AIProSubscriptionPromptContent(status: status),
            subscriptionService: subscriptionService
        )
    }
}

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
