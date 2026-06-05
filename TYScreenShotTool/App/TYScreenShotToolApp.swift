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
    private let captureSessionService: CaptureSessionService
    private let globalHotKeyService: GlobalHotKeyService

    init() {
        let overlayService = CaptureOverlayService()
        let sessionService = CaptureSessionService(overlayService: overlayService)

        overlayService.onCancel = {
            sessionService.cancelSession()
        }
        overlayService.onDragStarted = {
            sessionService.beginDragging()
        }
        overlayService.onSelectionCompleted = { rect in
            sessionService.completeSelection(rect)
        }

        let hotKeyService = GlobalHotKeyService(
            hotKey: .screenshot,
            onHotKeyPressed: {
                sessionService.startSession()
            }
        )

        _ = hotKeyService.register()

        self.captureOverlayService = overlayService
        self.captureSessionService = sessionService
        self.globalHotKeyService = hotKeyService
    }

    var body: some Scene {
        MenuBarExtra("ScreenshotTool", systemImage: "camera.viewfinder") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.menu)
    }
}
