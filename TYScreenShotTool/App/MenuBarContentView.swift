//
//  MenuBarContentView.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/5.
//

import AppKit
import SwiftUI

/// 菜单栏内容视图
///
/// 显示截图工具的菜单栏菜单项。
struct MenuBarContentView: View {
    private let settingsOpenCoordinator: SettingsOpenCoordinator

    init(settingsOpenCoordinator: SettingsOpenCoordinator) {
        self.settingsOpenCoordinator = settingsOpenCoordinator
    }

    var body: some View {
        Button(AppLocalization.text("app.name")) {
        }

        Divider()

        Button(AppLocalization.text("menu.settings")) {
            settingsOpenCoordinator.openSettings()
        }

        Divider()

        Button(AppLocalization.text("menu.quit")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
