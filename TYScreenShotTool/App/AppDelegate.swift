import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var captureSessionService: CaptureSessionService?
    private var globalHotKeyService: GlobalHotKeyService?
    private var settingsOpenCoordinator: SettingsOpenCoordinator?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        AppThemeCoordinator.shared.applyCurrentAppearance()

        // 恢复后端会话（Keychain 中的 Bearer Token）
        AIProSessionManager.shared.restoreSession()
#if DEBUG
        if runStoreKitDebugVerificationIfRequested() {
            return
        }
#endif
        if AIAvailabilityService().isSubscriptionAllowed {
            AIProSubscriptionService.shared.startTransactionListener()
        }

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
        let settingsCoordinator = SettingsOpenCoordinator()
        settingsCoordinator.configure {
            SettingsViewController(globalHotKeyService: hotKeyService)
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
            settingsOpenCoordinator: settingsCoordinator,
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
        overlayService.onTranslateRequested = { style, annotations in
            sessionService.translatePendingCapture(style: style, annotations: annotations)
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
        scrollingCapturePanelService.onTranslateRequested = {
            sessionService.translateScrollingCaptureResult()
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

        captureSessionService = sessionService
        globalHotKeyService = hotKeyService
        settingsOpenCoordinator = settingsCoordinator
        menuBarController = MenuBarController(settingsOpenCoordinator: settingsCoordinator)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private static func loadConfiguredHotKey() -> ScreenshotHotKey {
        let storageValue = UserDefaults.standard.string(forKey: AppSettings.screenshotHotKeyKey)
            ?? AppSettings.screenshotHotKeyDefaultValue
        return ScreenshotHotKey(storageValue: storageValue) ?? .screenshot
    }

#if DEBUG
    private func runStoreKitDebugVerificationIfRequested() -> Bool {
        let defaults = UserDefaults.standard
        guard
            let rawMode = defaults.string(forKey: AppSettings.debugStoreKitVerificationModeKey),
            let mode = AIProStoreKitDebugVerifier.Mode(rawValue: rawMode)
        else {
            return false
        }

        defaults.removeObject(forKey: AppSettings.debugStoreKitVerificationModeKey)
        Task { @MainActor in
            await AIProStoreKitDebugVerifier.run(mode: mode)
            NSApplication.shared.terminate(nil)
        }
        return true
    }
#endif
}
