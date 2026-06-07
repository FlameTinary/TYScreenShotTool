//
//  MenuBarContentView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/5.
//

import AppKit
import SwiftUI

struct MenuBarContentView: View {
    private let settingsOpenCoordinator: SettingsOpenCoordinator

    init(settingsOpenCoordinator: SettingsOpenCoordinator) {
        self.settingsOpenCoordinator = settingsOpenCoordinator
    }

    var body: some View {
        Button("TShot") {
        }

        Divider()

        Button("Settings") {
            settingsOpenCoordinator.openSettings()
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
