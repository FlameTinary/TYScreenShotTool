//
//  TYScreenShotToolApp.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/5.
//

import SwiftUI
import AppKit

@main
struct TYScreenShotToolApp: App {
    private let captureOverlayService: CaptureOverlayService
    private let captureSessionService: CaptureSessionService
    private let clipboardService: ClipboardService
    private let imageSaveService: ImageSaveService
    private let screenCaptureService: ScreenCaptureService
    private let globalHotKeyService: GlobalHotKeyService
    private let settingsOpenCoordinator: SettingsOpenCoordinator

    init() {
        let overlayService = CaptureOverlayService()
        let screenCaptureService = ScreenCaptureService()
        let clipboardService = ClipboardService()
        let imageSaveService = ImageSaveService()
        let hotKeyService = GlobalHotKeyService(
            hotKey: Self.loadConfiguredHotKey(),
            onHotKeyPressed: {}
        )
        let settingsOpenCoordinator = SettingsOpenCoordinator()
        settingsOpenCoordinator.configure {
            SettingsView(globalHotKeyService: hotKeyService)
        }
        let sessionService = CaptureSessionService(
            overlayService: overlayService,
            screenCaptureService: screenCaptureService,
            clipboardService: clipboardService,
            imageSaveService: imageSaveService,
            ocrService: OCRService(),
            settingsOpenCoordinator: settingsOpenCoordinator
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

        hotKeyService.onHotKeyPressed = {
            NSApplication.shared.activate(ignoringOtherApps: true)
            sessionService.startSession()
        }

        _ = hotKeyService.register()

        self.captureOverlayService = overlayService
        self.captureSessionService = sessionService
        self.clipboardService = clipboardService
        self.imageSaveService = imageSaveService
        self.screenCaptureService = screenCaptureService
        self.globalHotKeyService = hotKeyService
        self.settingsOpenCoordinator = settingsOpenCoordinator
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(settingsOpenCoordinator: settingsOpenCoordinator)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .accessibilityLabel("TShot")
        }
        .menuBarExtraStyle(.menu)
    }

    private static func loadConfiguredHotKey() -> ScreenshotHotKey {
        let storageValue = UserDefaults.standard.string(forKey: AppSettings.screenshotHotKeyKey)
            ?? AppSettings.screenshotHotKeyDefaultValue

        return ScreenshotHotKey(storageValue: storageValue) ?? .screenshot
    }
}
