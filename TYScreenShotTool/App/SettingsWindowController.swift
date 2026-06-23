//
//  SettingsWindowController.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    init(contentViewController: NSViewController) {
        let window = NSWindow(contentViewController: contentViewController)
        window.title = AppLocalization.text("window.settings.title")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 460, height: 360)
        window.setContentSize(NSSize(width: 520, height: 580))
        window.center()
        AppThemeCoordinator.shared.applyCurrentAppearance(to: window)
        super.init(window: window)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .appLanguageDidChange,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func languageDidChange() {
        window?.title = AppLocalization.text("window.settings.title")
        (contentViewController as? SettingsViewController)?.reloadLocalizedTexts()
    }
}
