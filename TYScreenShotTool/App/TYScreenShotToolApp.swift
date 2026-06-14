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
    private let pinWindowService: PinWindowService
    private let toastService: ToastService

    init() {
        let overlayService = CaptureOverlayService()
        let screenCaptureService = ScreenCaptureService()
        let clipboardService = ClipboardService()
        let imageSaveService = ImageSaveService()
        let pinWindowService = PinWindowService()
        let toastService = ToastService()
        let scrollingCaptureService = ScrollingCaptureService()
        let scrollingCapturePanelService = ScrollingCapturePanelService()
        let scrollingCapturePreviewWindowService = ScrollingCapturePreviewWindowService()
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
            pinWindowService: pinWindowService,
            toastService: toastService,
            settingsOpenCoordinator: settingsOpenCoordinator,
            scrollingCaptureService: scrollingCaptureService,
            scrollingCapturePanelService: scrollingCapturePanelService,
            scrollingCapturePreviewWindowService: scrollingCapturePreviewWindowService
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
        overlayService.onPreviewSelectionChanged = { rect in
            sessionService.updatePendingSelection(rect)
        }
        overlayService.onCopyRequested = { style, annotations in
            sessionService.copyPendingCapture(style: style, annotations: annotations)
        }
        overlayService.onSaveRequested = { style, annotations in
            sessionService.savePendingCapture(style: style, annotations: annotations)
        }
        overlayService.onOCRRequested = { style, annotations in
            sessionService.ocrPendingCapture(style: style, annotations: annotations)
        }
        overlayService.onPinRequested = { style, annotations in
            sessionService.pinPendingCapture(style: style, annotations: annotations)
        }
        overlayService.onLongCaptureRequested = { annotations in
            sessionService.startScrollingCapture(annotations: annotations)
        }
        scrollingCapturePanelService.onCancelRequested = {
            sessionService.cancelSession()
        }
        scrollingCapturePanelService.onCopyRequested = {
            sessionService.copyScrollingCaptureResult()
        }
        scrollingCapturePanelService.onSaveRequested = {
            sessionService.saveScrollingCaptureResult()
        }

        hotKeyService.onHotKeyPressed = {
            let sourceApplication = NSWorkspace.shared.frontmostApplication
            sessionService.setSourceApplication(sourceApplication)
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
        self.pinWindowService = pinWindowService
        self.toastService = toastService
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(settingsOpenCoordinator: settingsOpenCoordinator)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .accessibilityLabel("SmartShot")
        }
        .menuBarExtraStyle(.menu)
    }

    private static func loadConfiguredHotKey() -> ScreenshotHotKey {
        let storageValue = UserDefaults.standard.string(forKey: AppSettings.screenshotHotKeyKey)
            ?? AppSettings.screenshotHotKeyDefaultValue

        return ScreenshotHotKey(storageValue: storageValue) ?? .screenshot
    }
}
