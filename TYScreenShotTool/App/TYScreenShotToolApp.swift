//
//  TYScreenShotToolApp.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/5.
//

import SwiftUI

@main
struct TYScreenShotToolApp: App {
    private let captureOverlayService: CaptureOverlayService
    private let globalHotKeyService: GlobalHotKeyService

    init() {
        let overlayService = CaptureOverlayService()
        let hotKeyService = GlobalHotKeyService(
            hotKey: .screenshot,
            onHotKeyPressed: {
                overlayService.presentOverlay()
            }
        )

        _ = hotKeyService.register()

        self.captureOverlayService = overlayService
        self.globalHotKeyService = hotKeyService
    }

    var body: some Scene {
        MenuBarExtra("ScreenshotTool", systemImage: "camera.viewfinder") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.menu)
    }
}
