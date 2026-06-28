import AppKit

@MainActor
enum AIProPromptPresenter {
    static func show(from view: NSView?) {
        let alert = NSAlert()
        alert.messageText = AppText.aiProPromptTitle
        alert.informativeText = AppText.aiProPromptMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: AppText.aiProPromptPrimaryButton)

        if let window = view?.window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
