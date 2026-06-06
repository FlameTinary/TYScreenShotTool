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
    private let clipboardService: ClipboardService
    private let imageSaveService: ImageSaveService
    private let screenCaptureService: ScreenCaptureService
    private let globalHotKeyService: GlobalHotKeyService

    init() {
        let overlayService = CaptureOverlayService()
        let screenCaptureService = ScreenCaptureService()
        let clipboardService = ClipboardService()
        let imageSaveService = ImageSaveService()
        let sessionService = CaptureSessionService(
            overlayService: overlayService,
            screenCaptureService: screenCaptureService,
            clipboardService: clipboardService,
            imageSaveService: imageSaveService,
            ocrService: OCRService()
        )

        overlayService.onCancel = {
            sessionService.cancelSession()
        }
        overlayService.onDragStarted = {
            sessionService.beginDragging()
        }
        overlayService.onSelectionCompleted = { rect in
            sessionService.completeSelection(rect)
        }
        overlayService.onCopyRequested = { style in
            sessionService.copyPendingCapture(style: style)
        }
        overlayService.onSaveRequested = { style in
            sessionService.savePendingCapture(style: style)
        }

        let hotKeyService = GlobalHotKeyService(
            hotKey: Self.loadConfiguredHotKey(),
            onHotKeyPressed: {
                sessionService.startSession()
            }
        )

        _ = hotKeyService.register()

        self.captureOverlayService = overlayService
        self.captureSessionService = sessionService
        self.clipboardService = clipboardService
        self.imageSaveService = imageSaveService
        self.screenCaptureService = screenCaptureService
        self.globalHotKeyService = hotKeyService
    }

    var body: some Scene {
        MenuBarExtra("ScreenshotTool", systemImage: "camera.viewfinder") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(globalHotKeyService: globalHotKeyService)
        }
    }

    private static func loadConfiguredHotKey() -> ScreenshotHotKey {
        let storageValue = UserDefaults.standard.string(forKey: AppSettings.screenshotHotKeyKey)
            ?? AppSettings.screenshotHotKeyDefaultValue

        return ScreenshotHotKey(storageValue: storageValue) ?? .screenshot
    }
}
