//
//  SettingsOpenCoordinator.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/7.
//

import AppKit
import SwiftUI

@MainActor
final class SettingsOpenCoordinator {
    private var settingsWindow: NSWindow?
    private var contentProvider: (() -> AnyView)?

    func configure<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        contentProvider = {
            AnyView(content())
        }

        if let settingsWindow {
            refreshContentViewController(for: settingsWindow)
            return
        }

        let window = NSWindow()
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 460, height: 360)
        window.setContentSize(NSSize(width: 520, height: 420))
        window.center()
        refreshContentViewController(for: window)
        self.settingsWindow = window
    }

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

        let hostingController = NSHostingController(rootView: contentProvider())
        window.contentViewController = hostingController
    }
}
