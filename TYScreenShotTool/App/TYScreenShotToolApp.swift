//
//  TYScreenShotToolApp.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/5.
//

import SwiftUI
import AppKit

/// 截图工具应用入口
///
/// 菜单栏应用，提供全局快捷键截图功能。
/// 初始化所有服务组件并配置回调链。
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

    /// 应用主体
    ///
    /// 显示菜单栏图标和菜单内容。
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

    /// 加载用户配置的快捷键
    ///
    /// 从 UserDefaults 读取快捷键配置，如果未配置则使用默认值。
    ///
    /// - Returns: 用户配置或默认的快捷键
    private static func loadConfiguredHotKey() -> ScreenshotHotKey {
        let storageValue = UserDefaults.standard.string(forKey: AppSettings.screenshotHotKeyKey)
            ?? AppSettings.screenshotHotKeyDefaultValue

        return ScreenshotHotKey(storageValue: storageValue) ?? .screenshot
    }
}
