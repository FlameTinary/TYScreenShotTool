//
//  TYScreenShotToolApp.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/5.
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
        let ocrPreviewWindowService = OCRPreviewWindowService()
        let aiImageTextExtractionService = AIImageTextExtractionService()
        let aiAnalysisService = AIAnalysisService()
        let aiAnalysisPreviewWindowService = AIAnalysisPreviewWindowService()
        let windowSelectionService = WindowSelectionService()
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
            aiImageTextExtractionService: aiImageTextExtractionService,
            aiAnalysisService: aiAnalysisService,
            pinWindowService: pinWindowService,
            toastService: toastService,
            settingsOpenCoordinator: settingsOpenCoordinator,
            scrollingCaptureService: scrollingCaptureService,
            scrollingCapturePanelService: scrollingCapturePanelService,
            scrollingCapturePreviewWindowService: scrollingCapturePreviewWindowService,
            ocrPreviewWindowService: ocrPreviewWindowService,
            aiAnalysisPreviewWindowService: aiAnalysisPreviewWindowService
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
        overlayService.onWindowSelectionConfirmed = { candidate in
            sessionService.confirmWindowSelection(candidate)
        }
        overlayService.windowCandidateProvider = { screenPoint in
            windowSelectionService.candidateWindow(at: screenPoint)
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
        overlayService.onAIRequested = { mode, style, annotations in
            sessionService.analyzePendingCapture(
                mode: mode,
                style: style,
                annotations: annotations
            )
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
        scrollingCapturePanelService.onOCRRequested = {
            sessionService.ocrScrollingCaptureResult()
        }
        scrollingCapturePanelService.onAIRequested = { mode in
            sessionService.analyzeScrollingCaptureResult(mode: mode)
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
