//
//  MenuBarContentView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/5.
//

import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("ScreenshotTool") {
        }

        Divider()

        Button("Settings") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            openSettings()
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
