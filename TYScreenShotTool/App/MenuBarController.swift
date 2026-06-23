//
//  MenuBarController.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settingsOpenCoordinator: SettingsOpenCoordinator

    init(settingsOpenCoordinator: SettingsOpenCoordinator) {
        self.settingsOpenCoordinator = settingsOpenCoordinator
        super.init()
        configureStatusItem()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .appLanguageDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func languageDidChange() {
        rebuildMenu()
        statusItem.button?.setAccessibilityLabel(AppLocalization.text("app.name"))
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: AppText.openSettingsButton, action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: AppText.appQuit, action: #selector(quitApp), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func configureStatusItem() {
        if let image = NSImage(named: "MenuBarIcon") {
            statusItem.button?.image = image
        } else {
            statusItem.button?.image = NSImage(
                systemSymbolName: "camera.viewfinder",
                accessibilityDescription: nil
            )
        }
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.setAccessibilityLabel(AppLocalization.text("app.name"))
        rebuildMenu()
    }

    @objc private func openSettings() {
        settingsOpenCoordinator.openSettings()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
