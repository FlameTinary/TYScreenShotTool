//
//  MenuBarContentView.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/5.
//

import AppKit
import SwiftUI

struct MenuBarContentView: View {
    private let settingsOpenCoordinator: SettingsOpenCoordinator

    init(settingsOpenCoordinator: SettingsOpenCoordinator) {
        self.settingsOpenCoordinator = settingsOpenCoordinator
    }

    var body: some View {
        Button("SmartShot") {
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
