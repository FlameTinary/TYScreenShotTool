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

    func configure<Content: View>(@ViewBuilder content: () -> Content) {
        let hostingController = NSHostingController(rootView: content())

        if let settingsWindow {
            settingsWindow.contentViewController = hostingController
            return
        }

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 460, height: 360)
        window.setContentSize(NSSize(width: 520, height: 420))
        window.center()
        self.settingsWindow = window
    }

    func openSettings() {
        guard let settingsWindow else {
            return
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindow.makeKeyAndOrderFront(nil)
    }
}
