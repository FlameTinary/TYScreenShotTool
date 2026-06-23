//
//  SettingsOpenCoordinator.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/7.
//

import AppKit

/// 设置窗口协调器
///
/// 管理设置窗口的创建、显示和内容更新，确保窗口唯一性。
@MainActor
final class SettingsOpenCoordinator {
    private var settingsWindowController: SettingsWindowController?
    private var settingsViewController: SettingsViewController?

    func configure(contentProvider: @escaping () -> SettingsViewController) {
        let viewController = settingsViewController ?? contentProvider()
        settingsViewController = viewController

        if let settingsWindowController {
            settingsWindowController.contentViewController = viewController
            settingsWindowController.window?.title = AppLocalization.text("window.settings.title")
        }
    }

    func openSettings() {
        guard let settingsViewController else {
            return
        }

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                contentViewController: settingsViewController
            )
        } else {
            settingsWindowController?.contentViewController = settingsViewController
            settingsWindowController?.window?.title = AppLocalization.text("window.settings.title")
        }

        if let window = settingsWindowController?.window {
            AppThemeCoordinator.shared.applyCurrentAppearance(to: window)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }
}
