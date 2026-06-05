//
//  MenuBarContentView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/5.
//

import AppKit
import SwiftUI

struct MenuBarContentView: View {
    var body: some View {
        Button("ScreenshotTool") {
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
