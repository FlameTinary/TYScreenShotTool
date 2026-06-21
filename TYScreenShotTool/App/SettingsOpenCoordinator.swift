//
//  SettingsOpenCoordinator.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/7.
//

import AppKit
import SwiftUI

/// 设置窗口协调器
///
/// 管理设置窗口的创建、显示和内容更新，确保窗口唯一性。
@MainActor
final class SettingsOpenCoordinator {
    private var settingsWindow: NSWindow?
    private var contentProvider: (() -> AnyView)?

    /// 配置设置窗口内容
    ///
    /// 设置窗口内容提供者，如果窗口已存在则刷新内容。
    ///
    /// - Parameter content: 设置界面内容构建器
    func configure<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        contentProvider = {
            AnyView(content())
        }

        if let settingsWindow {
            refreshContentViewController(for: settingsWindow)
            return
        }

        let window = NSWindow()
        window.title = AppLocalization.text("window.settings.title")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 460, height: 360)
        window.setContentSize(NSSize(width: 520, height: 420))
        window.center()
        refreshContentViewController(for: window)
        self.settingsWindow = window
    }

    /// 打开设置窗口
    ///
    /// 激活应用并显示设置窗口，刷新窗口内容。
    func openSettings() {
        guard let settingsWindow else {
            return
        }

        refreshContentViewController(for: settingsWindow)
        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindow.makeKeyAndOrderFront(nil)
    }

    private func refreshContentViewController(for window: NSWindow) {
        guard let contentProvider else {
            return
        }

        window.title = AppLocalization.text("window.settings.title")
        let hostingController = NSHostingController(rootView: contentProvider())
        window.contentViewController = hostingController
    }
}
