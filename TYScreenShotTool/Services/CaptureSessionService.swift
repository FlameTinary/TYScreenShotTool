//
//  CaptureSessionService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/5.
//

import AppKit
import CoreGraphics
import CoreImage
import Foundation

/// 截图会话服务
///
/// 协调整个截图流程，管理状态转换和各服务间的交互。
final class CaptureSessionService {
    private enum PendingCaptureSource {
        case frozenScreenRect(CGRect)
        case independentWindow(windowID: CGWindowID, frame: CGRect)

        var selectionRect: CGRect {
            switch self {
            case let .frozenScreenRect(rect):
                return rect
            case let .independentWindow(_, frame):
                return frame
            }
        }
    }

    private enum AITextInputStrategy {
        case localOCR
        case visionAI

        var logName: String {
            switch self {
            case .localOCR:
                return "local_ocr"
            case .visionAI:
                return "vision_ai"
            }
        }
    }

    private let overlayService: CaptureOverlayService
    private let screenCaptureService: ScreenCaptureService
    private let clipboardService: ClipboardService
    private let imageSaveService: ImageSaveService
    private let ocrService: OCRService
    private let aiImageTextExtractionService: AIImageTextExtractionService
    private let pinWindowService: PinWindowService
    private let toastService: ToastService
    private let settingsOpenCoordinator: SettingsOpenCoordinator
    private let scrollingCaptureService: ScrollingCaptureService
    private let scrollingCapturePanelService: ScrollingCapturePanelService
    private let scrollingCapturePreviewWindowService: ScrollingCapturePreviewWindowService
    private let ocrPreviewWindowService: OCRPreviewWindowService
    private let aiAnalysisPreviewWindowService: AIAnalysisPreviewWindowService
    private let translationResultPanelService = TranslationResultPanelService()
    private let ciContext = CIContext()
    private var state: CaptureState = .idle
    private var pendingCaptureSource: PendingCaptureSource?
    private var pendingScreenImages: [CGDirectDisplayID: CGImage] = [:]
    private var sourceApplication: NSRunningApplication?
    private var isPreparingSession = false
    private var isInScrollingCaptureMode = false
    private var scrollingCaptureFrames: [CGImage] = []
    private var scrollingCaptureResultImage: CGImage?
    private var scrollingCaptureResultRevision = 0
    private var isAppendingScrollingFrame = false
    private var scrollingEventMonitor: Any?
    private var scrollingAppendTask: Task<Void, Never>?
    private var scrollingOCRRequestID = 0
    private var scrollingOCRInFlightRevision: Int?
    private var scrollingOCRTask: Task<Void, Never>?
    private var scrollingAIRequestID = UUID()
    private var isAIAnalysisInProgress = false
    private var pendingAIAnalysisMode: AIAnalysisMode?

    init(
        overlayService: CaptureOverlayService,
        screenCaptureService: ScreenCaptureService,
        clipboardService: ClipboardService,
        imageSaveService: ImageSaveService,
        ocrService: OCRService,
        aiImageTextExtractionService: AIImageTextExtractionService,
        pinWindowService: PinWindowService,
        toastService: ToastService,
        settingsOpenCoordinator: SettingsOpenCoordinator,
        scrollingCaptureService: ScrollingCaptureService,
        scrollingCapturePanelService: ScrollingCapturePanelService,
        scrollingCapturePreviewWindowService: ScrollingCapturePreviewWindowService,
        ocrPreviewWindowService: OCRPreviewWindowService,
        aiAnalysisPreviewWindowService: AIAnalysisPreviewWindowService
    ) {
        self.overlayService = overlayService
        self.screenCaptureService = screenCaptureService
        self.clipboardService = clipboardService
        self.imageSaveService = imageSaveService
        self.ocrService = ocrService
        self.aiImageTextExtractionService = aiImageTextExtractionService
        self.pinWindowService = pinWindowService
        self.toastService = toastService
        self.settingsOpenCoordinator = settingsOpenCoordinator
        self.scrollingCaptureService = scrollingCaptureService
        self.scrollingCapturePanelService = scrollingCapturePanelService
        self.scrollingCapturePreviewWindowService = scrollingCapturePreviewWindowService
        self.ocrPreviewWindowService = ocrPreviewWindowService
        self.aiAnalysisPreviewWindowService = aiAnalysisPreviewWindowService
    }

    func startSession() {
        guard state == .idle, isPreparingSession == false else {
            return
        }

        isPreparingSession = true

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            defer {
                self.isPreparingSession = false
            }

            do {
                self.pendingScreenImages = try await self.screenCaptureService.captureScreenImages()
                self.transition(to: .overlayPresented)
                self.overlayService.presentOverlay(screenImages: self.pendingScreenImages)
            } catch ScreenCaptureError.permissionRequired {
                TYLogger.warn("Screen Recording permission required.", tag: "CaptureSession")
                TYLogger.warn("Please restart the app after granting permission.", tag: "CaptureSession")
            } catch {
                TYLogger.error("Capture prepare failed", tag: "CaptureSession", error: error)
            }
        }
    }

    func setSourceApplication(_ application: NSRunningApplication?) {
        guard let application,
              application.bundleIdentifier != Bundle.main.bundleIdentifier else {
            sourceApplication = nil
            return
        }

        sourceApplication = application
    }

    func beginDragging() {
        guard state == .overlayPresented else {
            return
        }

        transition(to: .dragging)
    }

    /// 完成截图选择
    ///
    /// - Parameters:
    ///   - rect: 选择区域
    func completeSelection(_ rect: CGRect) {
        guard state == .dragging else {
            return
        }

        guard rect.width > 1, rect.height > 1 else {
            TYLogger.warn("Capture skipped: invalid selection", tag: "CaptureSession")
            overlayService.dismissOverlay()
            transition(to: .selectionCompleted)
            transition(to: .idle)
            return
        }

        transition(to: .selectionCompleted)
        logSelection(rect)
        pendingCaptureSource = .frozenScreenRect(rect)
        overlayService.showSelectionPreview(selectionRect: rect, screenImages: pendingScreenImages)
    }

    /// 确认窗口选择
    ///
    /// - Parameters:
    ///   - candidate: 窗口选择候选
    /// - Returns: 确认结果
    /// - Throws: 确认失败时抛出错误
    func confirmWindowSelection(_ candidate: WindowSelectionCandidate) {
        guard state == .overlayPresented else {
            return
        }

        let rect = candidate.frame
        guard rect.width > 1, rect.height > 1 else {
            return
        }

        transition(to: .selectionCompleted)
        logSelection(rect)
        pendingCaptureSource = .independentWindow(windowID: candidate.windowID, frame: rect)
        overlayService.showSelectionPreview(selectionRect: rect, screenImages: pendingScreenImages)
    }

    /// 更新待截图选择区域
    ///
    /// - Parameters:
    ///   - rect: 新的选择区域
    func updatePendingSelection(_ rect: CGRect) {
        guard state == .selectionCompleted else {
            return
        }

        guard rect.width > 1, rect.height > 1 else {
            return
        }

        pendingCaptureSource = .frozenScreenRect(rect)
    }
    /// 取消截图会话
    ///
    /// 清除所有待截图数据并关闭会话。
    /// 移除状态 guard 确保任何状态下都能强制清理，避免 session 卡死。
    func cancelSession() {
        if isInScrollingCaptureMode {
            cancelScrollingCapture()
        }

        isPreparingSession = false
        isAIAnalysisInProgress = false
        overlayService.setAIButtonEnabled(true)
        ocrPreviewWindowService.dismiss()
        aiAnalysisPreviewWindowService.dismiss()
        clearPendingCapture()
        overlayService.dismissOverlay()
        transition(to: .idle)
    }

    /// 复制待截图到剪贴板
    ///
    /// - Parameters:
    ///   - style: 截图预览样式
    ///   - annotations: 截图注释
    /// - Returns: 复制结果
    /// - Throws: 复制失败时抛出错误
    func copyPendingCapture(style: CapturePreviewStyle, annotations: [CaptureAnnotation]) {
        guard state == .selectionCompleted, let pendingCaptureSource else {
            return
        }

        ocrPreviewWindowService.dismiss()
        aiAnalysisPreviewWindowService.dismiss()
        Task {
            do {
                let selectionRect = pendingCaptureSource.selectionRect
                let image = try await captureImageForPendingSource(pendingCaptureSource)
                let exportedImage = try exportedImage(
                    from: image,
                    style: style,
                    annotations: annotations,
                    previewSize: selectionRect.size
                )
                try clipboardService.copyImage(exportedImage)
                TYLogger.info("Clipboard Copy Success", tag: "CaptureSession")
                await MainActor.run {
                    toastService.showToast(message: AppText.screenshotCopiedToast)
                    overlayService.dismissOverlay()
                }
                clearPendingCapture()
                transition(to: .idle)
            } catch ScreenCaptureError.invalidSelection {
                TYLogger.warn("Capture skipped: invalid selection", tag: "CaptureSession")
            } catch let error as ClipboardError {
                TYLogger.error("Clipboard copy failed", tag: "CaptureSession", error: error)
            } catch {
                TYLogger.error("Clipboard copy failed", tag: "CaptureSession", error: error)
            }
        }
    }

    /// 保存待截图
    ///
    /// - Parameters:
    ///   - style: 截图预览样式
    ///   - annotations: 截图注释
    /// - Returns: 保存的文件 URL
    /// - Throws: 保存失败时抛出错误
    func savePendingCapture(style: CapturePreviewStyle, annotations: [CaptureAnnotation]) {
        guard state == .selectionCompleted, let pendingCaptureSource else {
            return
        }

        ocrPreviewWindowService.dismiss()
        aiAnalysisPreviewWindowService.dismiss()
        Task {
            var temporaryFileURL: URL?

            do {
                let selectionRect = pendingCaptureSource.selectionRect
                let image = try await captureImageForPendingSource(pendingCaptureSource)
                let exportedImage = try exportedImage(
                    from: image,
                    style: style,
                    annotations: annotations,
                    previewSize: selectionRect.size
                )
                temporaryFileURL = try imageSaveService.saveTemporaryPNG(exportedImage)
                let savedFileURL = try imageSaveService.moveImageToConfiguredDirectory(from: temporaryFileURL!)
                TYLogger.info("Save Success", tag: "CaptureSession")
                TYLogger.debug("path: \(savedFileURL.path)", tag: "CaptureSession")
                await MainActor.run {
                    toastService.showToast(message: AppText.screenshotSavedToast)
                    overlayService.dismissOverlay()
                }
                clearPendingCapture()
                transition(to: .idle)
            } catch ScreenCaptureError.invalidSelection {
                TYLogger.warn("Capture skipped: invalid selection", tag: "CaptureSession")
            } catch let error as ImageSaveError {
                if let temporaryFileURL {
                    cleanupTemporaryImage(at: temporaryFileURL)
                }
                finishFailedSaveSession()
                TYLogger.error("Save failed", tag: "CaptureSession", error: error)
                presentSaveAlertIfNeeded(for: error)
            } catch {
                if let temporaryFileURL {
                    cleanupTemporaryImage(at: temporaryFileURL)
                }
                finishFailedSaveSession()
                TYLogger.error("Save failed", tag: "CaptureSession", error: error)
            }
        }
    }
    /// 对待截图进行本地翻译（OCR → SwiftUI translationTask 内调用 Translation.framework）
    ///
    /// - Parameters:
    ///   - style: 截图预览样式
    ///   - annotations: 截图注释
    func translatePendingCapture(style: CapturePreviewStyle, annotations: [CaptureAnnotation]) {
        guard state == .selectionCompleted, let pendingCaptureSource else {
            return
        }

        Task {
            do {
                let selectionRect = pendingCaptureSource.selectionRect
                let image = try await captureImageForPendingSource(pendingCaptureSource)

                // Step 1: OCR
                let ocrText = try ocrService.recognizeText(in: image)
                let trimmedText = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)

                guard trimmedText.isEmpty == false else {
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        translationResultPanelService.presentResult(
                            sourceText: "",
                            translatedText: AppLocalization.text("translate.empty_text"),
                            selectionRect: selectionRect,
                            onCopySource: { _ in },
                            onCopyTarget: { _ in },
                            onClose: { [weak self] in
                                self?.translationResultPanelService.dismiss()
                            }
                        )
                    }
                    return
                }

                // Step 2: 打开翻译窗口，翻译在 SwiftUI translationTask 中完成
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    translationResultPanelService.presentTranslating(
                        sourceText: trimmedText,
                        selectionRect: selectionRect,
                        onCopySource: { [weak self] text in
                            self?.copyTranslationSourceText(text)
                        },
                        onCopyTarget: { [weak self] text in
                            self?.copyTranslationTargetText(text)
                        },
                        onClose: { [weak self] in
                            self?.translationResultPanelService.dismiss()
                        }
                    )
                }
            } catch {
                TYLogger.error("Translation OCR failed", tag: "CaptureSession", error: error)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    toastService.showToast(message: AppText.ocrFailedToast)
                }
            }
        }
    }

    /// 对待截图进行 OCR 识别
    ///
    /// - Parameters:
    ///   - style: 截图预览样式
    ///   - annotations: 截图注释
    /// - Returns: 识别到的文本
    func ocrPendingCapture(style: CapturePreviewStyle, annotations: [CaptureAnnotation]) {
        guard state == .selectionCompleted, let pendingCaptureSource else {
            return
        }

        Task {
            do {
                let selectionRect = pendingCaptureSource.selectionRect
                let image = try await captureImageForPendingSource(pendingCaptureSource)
                let text = try ocrService.recognizeText(in: image)
                TYLogger.info("OCR Success", tag: "CaptureSession")
                TYLogger.debug("text: \(text)", tag: "CaptureSession")
                await MainActor.run {
                    ocrPreviewWindowService.present(
                        text: text,
                        selectionRect: selectionRect,
                        onCopy: { [weak self] in
                            self?.copyOCRPreviewText(text)
                        },
                        onCancel: { [weak self] in
                            self?.ocrPreviewWindowService.dismiss()
                        }
                    )
                }
            } catch {
                TYLogger.error("OCR failed", tag: "CaptureSession", error: error)
                await MainActor.run {
                    toastService.showToast(message: AppText.ocrFailedToast)
                }
            }
        }
    }

    func analyzePendingCapture(
        mode: AIAnalysisMode,
        style _: CapturePreviewStyle,
        annotations _: [CaptureAnnotation]
    ) {
        guard state == .selectionCompleted, let pendingCaptureSource else {
            return
        }

        guard isAIAnalysisInProgress == false else {
            toastService.showToast(message: AppText.aiInProgressToast)
            return
        }

        pendingAIAnalysisMode = mode
        let selectionRect = pendingCaptureSource.selectionRect
        isAIAnalysisInProgress = true
        overlayService.setAIButtonEnabled(false)
        ocrPreviewWindowService.dismiss()
        aiAnalysisPreviewWindowService.presentLoading(
            selectionRect: selectionRect,
            message: mode.loadingMessage,
            onClose: { [weak self] in
                self?.aiAnalysisPreviewWindowService.dismiss()
            }
        )

        Task { [weak self] in
            guard let self else {
                return
            }

            await self.performAIAnalysis(for: pendingCaptureSource, mode: mode)
        }
    }

    @MainActor
    func hidePendingCaptureUIForAIPrompt() {
        guard state == .selectionCompleted else {
            return
        }

        overlayService.hideActiveOverlay()
    }

    func pinPendingCapture(style: CapturePreviewStyle, annotations: [CaptureAnnotation]) {
        guard state == .selectionCompleted, let pendingCaptureSource else {
            return
        }

        ocrPreviewWindowService.dismiss()
        aiAnalysisPreviewWindowService.dismiss()
        Task { @MainActor in
            do {
                let selectionRect = pendingCaptureSource.selectionRect
                let exportedImage = try await prepareExportedImage(
                    for: pendingCaptureSource,
                    style: style,
                    annotations: annotations
                )
                pinWindowService.presentPinnedImage(exportedImage, sourceRect: selectionRect)
                TYLogger.info("Pin Success", tag: "CaptureSession")
                overlayService.dismissOverlay()
                clearPendingCapture()
                transition(to: .idle)
            } catch {
                TYLogger.error("Pin failed", tag: "CaptureSession", error: error)
            }
        }
    }

    func startScrollingCapture(annotations: [CaptureAnnotation]) {
        guard state == .selectionCompleted, isInScrollingCaptureMode == false, let pendingCaptureSource else {
            return
        }

        let pendingSelectionRect = pendingCaptureSource.selectionRect

        guard annotations.isEmpty else {
            TYLogger.warn("Scrolling capture failed: current selection contains annotations.", tag: "CaptureSession")
            toastService.showToast(message: AppText.scrollingCaptureAnnotationBlocked)
            return
        }

        ocrPreviewWindowService.dismiss()
        aiAnalysisPreviewWindowService.dismiss()
        invalidateScrollingOCRRequest()
        scrollingCaptureFrames.removeAll()
        scrollingCaptureResultImage = nil
        scrollingCaptureResultRevision = 0
        isAppendingScrollingFrame = false
        isInScrollingCaptureMode = true
        overlayService.enterLongCaptureGuideMode()
        if let screen = screenContaining(pendingSelectionRect) {
            scrollingCapturePanelService.presentCapturePanel(selectionRect: pendingSelectionRect, on: screen)
        } else if let screen = NSScreen.main ?? NSScreen.screens.first {
            scrollingCapturePanelService.presentCapturePanel(selectionRect: pendingSelectionRect, on: screen)
        }
        scrollingCapturePreviewWindowService.presentPreparingPreview(
            selectionRect: pendingSelectionRect,
            toolbarScreenRect: scrollingCapturePanelService.toolbarScreenFrame
        )
        pendingScreenImages.removeAll()
        reactivateSourceApplicationForScrolling()

        TYLogger.info("Scrolling Capture Started", tag: "CaptureSession")

        captureInitialScrollingFrame(for: pendingSelectionRect)
        installScrollingEventMonitor(for: pendingSelectionRect)
    }

    /// 追加长截图帧
    ///
    /// 追加当前选择区域的长截图帧到滚动截图结果中。
    func appendScrollingCaptureFrame() {
        guard isInScrollingCaptureMode, let pendingSelectionRect = pendingCaptureSource?.selectionRect else {
            return
        }

        appendScrollingCaptureFrameIfNeeded(for: pendingSelectionRect, requiresVisualChange: true)
    }

    /// 复制长截图结果到剪贴板
    ///
    /// 复制当前滚动截图结果到剪贴板。
    func copyScrollingCaptureResult() {
        guard isInScrollingCaptureMode, let image = scrollingCaptureResultImage else {
            return
        }

        invalidateScrollingOCRRequest()

        do {
            try clipboardService.copyImage(image)
            TYLogger.info("Scrolling Capture Copy Success", tag: "CaptureSession")
            toastService.showToast(message: AppText.longScreenshotCopiedToast)
            finishScrollingCaptureSession()
        } catch {
            TYLogger.error("Scrolling capture copy failed", tag: "CaptureSession", error: error)
        }
    }

    func saveScrollingCaptureResult() {
        guard isInScrollingCaptureMode, let image = scrollingCaptureResultImage else {
            return
        }

        invalidateScrollingOCRRequest()

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            var temporaryFileURL: URL?

            do {
                temporaryFileURL = try self.imageSaveService.saveTemporaryPNG(image)
                let savedFileURL = try self.imageSaveService.moveImageToConfiguredDirectory(from: temporaryFileURL!)
                TYLogger.info("Scrolling Capture Save Success", tag: "CaptureSession")
                TYLogger.debug("path: \(savedFileURL.path)", tag: "CaptureSession")
                self.toastService.showToast(message: AppText.longScreenshotSavedToast)
                self.finishScrollingCaptureSession()
            } catch let error as ImageSaveError {
                if let temporaryFileURL {
                    self.cleanupTemporaryImage(at: temporaryFileURL)
                }
                TYLogger.error("Scrolling capture save failed", tag: "CaptureSession", error: error)
                self.presentSaveAlertIfNeeded(for: error)
            } catch {
                if let temporaryFileURL {
                    self.cleanupTemporaryImage(at: temporaryFileURL)
                }
                TYLogger.error("Scrolling capture save failed", tag: "CaptureSession", error: error)
            }
        }
    }

    /// 对长截图结果进行OCR识别
    ///
    /// 对当前滚动截图结果进行OCR识别，并在识别完成后展示预览窗口。
    func ocrScrollingCaptureResult() {
        guard isInScrollingCaptureMode,
              let image = scrollingCaptureResultImage,
              let selectionRect = pendingCaptureSource?.selectionRect else {
            return
        }

        let resultRevision = scrollingCaptureResultRevision
        guard scrollingOCRInFlightRevision != resultRevision else {
            return
        }

        invalidateScrollingAIRequest()
        aiAnalysisPreviewWindowService.dismiss()
        let requestID = beginScrollingOCRRequest(for: resultRevision)
        let preferredSide = preferredResultSideForScrollingPreview()

        scrollingOCRTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let text = try self.ocrService.recognizeText(in: image)
                await MainActor.run {
                    guard self.shouldAcceptScrollingOCRResult(
                        requestID: requestID,
                        resultRevision: resultRevision
                    ) else {
                        return
                    }

                    self.finishScrollingOCRRequest(requestID: requestID)
                    self.ocrPreviewWindowService.present(
                        text: text,
                        selectionRect: selectionRect,
                        preferredSide: preferredSide,
                        onCopy: { [weak self] in
                            self?.copyScrollingOCRPreviewText(text)
                        },
                        onCancel: { [weak self] in
                            self?.ocrPreviewWindowService.dismiss()
                        }
                    )
                }
            } catch {
                await MainActor.run {
                    guard self.shouldAcceptScrollingOCRResult(
                        requestID: requestID,
                        resultRevision: resultRevision
                    ) else {
                        return
                    }

                    self.finishScrollingOCRRequest(requestID: requestID)
                    self.toastService.showToast(message: AppText.ocrFailedToast)
                }
            }
        }
    }

    /// 对长截图结果进行本地翻译
    ///
    /// 对当前滚动截图结果进行 OCR 识别，在 SwiftUI translationTask 内翻译，展示结果。
    func translateScrollingCaptureResult() {
        guard isInScrollingCaptureMode,
              let image = scrollingCaptureResultImage,
              let selectionRect = pendingCaptureSource?.selectionRect else {
            return
        }

        Task {
            do {
                // Step 1: OCR
                let ocrText = try ocrService.recognizeText(in: image)
                let trimmedText = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)

                guard trimmedText.isEmpty == false else {
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        translationResultPanelService.presentResult(
                            sourceText: "",
                            translatedText: AppLocalization.text("translate.empty_text"),
                            selectionRect: selectionRect,
                            onCopySource: { _ in },
                            onCopyTarget: { _ in },
                            onClose: { [weak self] in
                                self?.translationResultPanelService.dismiss()
                            }
                        )
                    }
                    return
                }

                // Step 2: 打开翻译窗口，翻译在 SwiftUI translationTask 中完成
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    translationResultPanelService.presentTranslating(
                        sourceText: trimmedText,
                        selectionRect: selectionRect,
                        onCopySource: { [weak self] text in
                            self?.copyTranslationSourceText(text)
                        },
                        onCopyTarget: { [weak self] text in
                            self?.copyTranslationTargetText(text)
                        },
                        onClose: { [weak self] in
                            self?.translationResultPanelService.dismiss()
                        }
                    )
                }
            } catch {
                TYLogger.error("Translation OCR failed", tag: "CaptureSession", error: error)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    toastService.showToast(message: AppText.ocrFailedToast)
                }
            }
        }
    }

    func analyzeScrollingCaptureResult(mode: AIAnalysisMode) {
        guard isInScrollingCaptureMode,
              let image = scrollingCaptureResultImage,
              let selectionRect = pendingCaptureSource?.selectionRect else {
            return
        }

        pendingAIAnalysisMode = mode
        let resultRevision = scrollingCaptureResultRevision
        invalidateScrollingOCRRequest()
        ocrPreviewWindowService.dismiss()
        let requestID = UUID()
        scrollingAIRequestID = requestID
        let preferredSide = preferredResultSideForScrollingPreview()

        aiAnalysisPreviewWindowService.presentLoading(
            selectionRect: selectionRect,
            preferredSide: preferredSide,
            message: mode.loadingMessage,
            onClose: { [weak self] in
                self?.scrollingAIRequestID = UUID()
                self?.aiAnalysisPreviewWindowService.dismiss()
            }
        )

        Task { [weak self] in
            await self?.performScrollingAIAnalysis(
                image: image,
                selectionRect: selectionRect,
                preferredSide: preferredSide,
                resultRevision: resultRevision,
                requestID: requestID,
                mode: mode
            )
        }
    }

    @MainActor
    func hideScrollingCaptureUIForAIPrompt() {
        guard isInScrollingCaptureMode else {
            return
        }

        scrollingCapturePanelService.dismissPanel()
        scrollingCapturePreviewWindowService.dismissPreview()
    }

    private func frozenSelectionImage(for selectionRect: CGRect) throws -> CGImage {
        guard selectionRect.width > 1, selectionRect.height > 1 else {
            throw ScreenCaptureError.invalidSelection
        }

        guard let screen = screenContaining(selectionRect) else {
            throw ScreenCaptureError.displayNotFound
        }

        guard screen.frame.minX <= selectionRect.minX,
              screen.frame.maxX >= selectionRect.maxX,
              screen.frame.minY <= selectionRect.minY,
              screen.frame.maxY >= selectionRect.maxY else {
            throw FrozenCaptureExportError.selectionSpansMultipleDisplays
        }

        let displayID = try displayID(for: screen)

        guard let screenImage = pendingScreenImages[displayID] else {
            throw FrozenCaptureExportError.cachedScreenImageMissing
        }

        return try screenCaptureService.cropImage(
            screenImage,
            in: screen.frame,
            to: selectionRect
        )
    }

    private func captureImageForPendingSource(_ source: PendingCaptureSource) async throws -> CGImage {
        switch source {
        case let .frozenScreenRect(rect):
            return try frozenSelectionImage(for: rect)
        case let .independentWindow(windowID, _):
            return try await screenCaptureService.captureImage(forWindowID: windowID)
        }
    }

    private func prepareExportedImage(
        for source: PendingCaptureSource,
        style: CapturePreviewStyle,
        annotations: [CaptureAnnotation]
    ) async throws -> CGImage {
        let image = try await captureImageForPendingSource(source)
        let selectionRect = source.selectionRect
        return try exportedImage(
            from: image,
            style: style,
            annotations: annotations,
            previewSize: selectionRect.size
        )
    }

    private func transition(to newState: CaptureState) {
        let oldState = state
        state = newState
        TYLogger.debug("\(oldState.displayName) -> \(newState.displayName)", tag: "CaptureSession")
    }

    private func currentAITextInputStrategy() -> AITextInputStrategy {
        let useVision = UserDefaults.standard.bool(forKey: AppSettings.aiUseVisionTextExtractionKey)
        TYLogger.debug("Settings aiUseVisionTextExtraction: \(useVision)", tag: "AI Analysis")
        if useVision {
            TYLogger.debug("Scrolling capture uses local OCR before backend analysis", tag: "AI Analysis")
        }
        return .localOCR
    }

    private func logSelection(_ rect: CGRect) {
        TYLogger.debug("Selection Rect", tag: "CaptureSession")
        TYLogger.debug("x: \(Int(rect.origin.x))", tag: "CaptureSession")
        TYLogger.debug("y: \(Int(rect.origin.y))", tag: "CaptureSession")
        TYLogger.debug("width: \(Int(rect.width))", tag: "CaptureSession")
        TYLogger.debug("height: \(Int(rect.height))", tag: "CaptureSession")
    }

    private func clearPendingCapture() {
        TYLogger.debug("closing translation window because screenshot session ended", tag: "CaptureSession")
        translationResultPanelService.dismiss()
        pendingCaptureSource = nil
        pendingAIAnalysisMode = nil
        pendingScreenImages.removeAll()
        scrollingCaptureFrames.removeAll()
        scrollingCaptureResultImage = nil
        scrollingCaptureResultRevision = 0
        isAppendingScrollingFrame = false
        removeScrollingEventMonitor()
        scrollingAppendTask?.cancel()
        scrollingAppendTask = nil
        invalidateScrollingOCRRequest()
        isInScrollingCaptureMode = false
        isAIAnalysisInProgress = false
    }

    private func screenContaining(_ rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.contains(CGPoint(x: rect.midX, y: rect.midY))
        }
    }

    private func displayID(for screen: NSScreen) throws -> CGDirectDisplayID {
        guard
            let value = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            throw ScreenCaptureError.displayNotFound
        }

        return CGDirectDisplayID(value.uint32Value)
    }

    private func cleanupTemporaryImage(at url: URL) {
        do {
            try imageSaveService.removeImage(at: url)
        } catch {
            TYLogger.error("Temporary image cleanup failed", tag: "CaptureSession", error: error)
        }
    }

    @MainActor
    private func copyOCRPreviewText(_ text: String) {
        do {
            try clipboardService.copyText(text)
            TYLogger.info("Clipboard Copy Success", tag: "CaptureSession")
            toastService.showToast(message: AppText.ocrCopiedToast)
            ocrPreviewWindowService.dismiss()
            overlayService.dismissOverlay()
            clearPendingCapture()
            transition(to: .idle)
        } catch {
            TYLogger.error("OCR clipboard copy failed", tag: "CaptureSession", error: error)
            toastService.showToast(message: AppText.ocrCopyFailedToast)
        }
    }

    @MainActor
    private func copyScrollingOCRPreviewText(_ text: String) {
        do {
            try clipboardService.copyText(text)
            toastService.showToast(message: AppText.ocrCopiedToast)
            ocrPreviewWindowService.dismiss()
        } catch {
            toastService.showToast(message: AppText.ocrCopyFailedToast)
        }
    }

    @MainActor
    private func copyTranslationSourceText(_ text: String) {
        do {
            try clipboardService.copyText(text)
            toastService.showToast(message: AppLocalization.text("translate.copied"))
            translationResultPanelService.dismiss()
        } catch {
            toastService.showToast(message: AppLocalization.text("translate.copy_failed"))
        }
    }

    @MainActor
    private func copyTranslationTargetText(_ text: String) {
        do {
            try clipboardService.copyText(text)
            toastService.showToast(message: AppLocalization.text("translate.copied"))
            translationResultPanelService.dismiss()
        } catch {
            toastService.showToast(message: AppLocalization.text("translate.copy_failed"))
        }
    }

    @MainActor
    private func performAIAnalysis(
        for source: PendingCaptureSource,
        mode: AIAnalysisMode
    ) async {
        let selectionRect = source.selectionRect

        TYLogger.info("mode: \(mode.menuTitle)", tag: "AI Analysis")

        defer {
            isAIAnalysisInProgress = false
            overlayService.setAIButtonEnabled(true)
        }

        do {
            let image = try await captureImageForPendingSource(source)

            let useVision = UserDefaults.standard.bool(forKey: AppSettings.aiUseVisionTextExtractionKey)
            TYLogger.debug("aiUseVisionTextExtraction: \(useVision)", tag: "AI Analysis")

            if useVision {
                await performBackendAIAnalysis(image: image, source: source, mode: mode)
            } else {
                await performLocalExtractBackendAnalysis(image: image, source: source, mode: mode)
            }
        } catch {
            toastService.showToast(message: AppText.aiFailedToast)
            aiAnalysisPreviewWindowService.presentError(
                title: AppText.aiResultError,
                message: error.localizedDescription,
                selectionRect: selectionRect,
                onRetry: { [weak self] in
                    self?.retryAIAnalysis()
                },
                onClose: { [weak self] in
                    self?.aiAnalysisPreviewWindowService.dismiss()
                }
            )
        }
    }

    /// 走后端 AI 分析链路（唯一路径）
    @MainActor
    private func performBackendAIAnalysis(
        image: CGImage,
        source: PendingCaptureSource,
        mode: AIAnalysisMode
    ) async {
        let selectionRect = source.selectionRect
        let backendClient = AIProBackendClient()
        let requestID = UUID().uuidString

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            "public.png" as CFString,
            1,
            nil
        ) else {
            toastService.showToast(message: AppText.aiFailedToast)
            aiAnalysisPreviewWindowService.presentError(
                title: AppText.aiResultError,
                message: AppText.aiFailedToast,
                selectionRect: selectionRect,
                onRetry: { [weak self] in
                    self?.retryAIAnalysis()
                },
                onClose: { [weak self] in
                    self?.aiAnalysisPreviewWindowService.dismiss()
                }
            )
            return
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            toastService.showToast(message: AppText.aiFailedToast)
            aiAnalysisPreviewWindowService.presentError(
                title: AppText.aiResultError,
                message: AppText.aiFailedToast,
                selectionRect: selectionRect,
                onRetry: { [weak self] in
                    self?.retryAIAnalysis()
                },
                onClose: { [weak self] in
                    self?.aiAnalysisPreviewWindowService.dismiss()
                }
            )
            return
        }
        let imageBase64 = (mutableData as Data).base64EncodedString()

        do {
            let response = try await backendClient.analyzeScreenshot(
                requestID: requestID,
                imageBase64: imageBase64,
                prompt: mode.backendPrompt
            )

            let result = AIAnalysisResult(
                mode: mode,
                statusTitle: mode.resultStatusTitle,
                sections: [
                    AIAnalysisSection(title: mode.resultStatusTitle, content: response.analysis)
                ],
                rawText: response.analysis,
                secondaryCopyText: response.analysis
            )

            TYLogger.info("Analysis success, model: \(response.model)", tag: "AI Pro Backend")

            aiAnalysisPreviewWindowService.presentResult(
                result: result,
                selectionRect: selectionRect,
                onCopyAll: { [weak self] in
                    self?.copyAIAnalysisResult(result.formattedText)
                },
                onCopyNextSteps: { [weak self] in
                    self?.copyAIAnalysisSecondaryText(
                        result.secondaryCopyText,
                        successMessage: result.mode.secondaryCopySuccessMessage
                    )
                },
                onRetry: { [weak self] in
                    self?.retryAIAnalysis()
                },
                onClose: { [weak self] in
                    self?.aiAnalysisPreviewWindowService.dismiss()
                }
            )

        } catch let error as AIProBackendError {
            switch error {
            case .authRequired, .subscriptionRequired:
                TYLogger.warn("Backend rejected: \(error.localizedDescription)", tag: "AI Pro Backend")
                toastService.showToast(message: error.localizedDescription)
                aiAnalysisPreviewWindowService.presentError(
                    title: AppText.aiResultError,
                    message: error.localizedDescription,
                    selectionRect: selectionRect,
                    onRetry: { [weak self] in
                        self?.retryAIAnalysis()
                    },
                    onClose: { [weak self] in
                        self?.aiAnalysisPreviewWindowService.dismiss()
                    }
                )
            default:
                TYLogger.error("Backend error: \(error.localizedDescription)", tag: "AI Pro Backend")
                toastService.showToast(message: error.localizedDescription)
                aiAnalysisPreviewWindowService.presentError(
                    title: AppText.aiResultError,
                    message: error.localizedDescription,
                    selectionRect: selectionRect,
                    onRetry: { [weak self] in
                        self?.retryAIAnalysis()
                    },
                    onClose: { [weak self] in
                        self?.aiAnalysisPreviewWindowService.dismiss()
                    }
                )
            }
        } catch {
            TYLogger.error("Unexpected error: \(error.localizedDescription)", tag: "AI Pro Backend")
            toastService.showToast(message: AppText.aiFailedToast)
            aiAnalysisPreviewWindowService.presentError(
                title: AppText.aiResultError,
                message: error.localizedDescription,
                selectionRect: selectionRect,
                onRetry: { [weak self] in
                    self?.retryAIAnalysis()
                },
                onClose: { [weak self] in
                    self?.aiAnalysisPreviewWindowService.dismiss()
                }
            )
        }
    }

    /// 先本地 OCR 提取文字，然后走后端文字分析接口
    /// 当 `aiUseVisionTextExtraction` 关闭时使用此路径
    private func performLocalExtractBackendAnalysis(
        image: CGImage,
        source: PendingCaptureSource,
        mode: AIAnalysisMode
    ) async {
        let selectionRect = source.selectionRect
        let backendClient = AIProBackendClient()
        let requestID = UUID().uuidString

        // Step 1: 本地 OCR 提取文字（在当前线程执行，不会阻塞主线程）
        TYLogger.info("Extracting text via local OCR for backend text analysis", tag: "AI Analysis")

        let extractedText: String
        do {
            extractedText = try ocrService.recognizeText(in: image)
        } catch let error as OCRError {
            await MainActor.run { [weak self] in
                guard let self, self.isAIAnalysisInProgress else { return }

                switch error {
                case .noTextRecognized, .emptyText:
                    TYLogger.warn("Local OCR produced no text", tag: "AI Analysis")
                    self.toastService.showToast(message: self.emptyContentMessage(for: mode))
                    self.aiAnalysisPreviewWindowService.dismiss()
                case .requestFailed:
                    TYLogger.error("Local OCR failed", tag: "AI Analysis", error: error)
                    self.toastService.showToast(message: AppText.ocrFailedToast)
                    self.aiAnalysisPreviewWindowService.presentError(
                        title: AppText.ocrFailedToast,
                        message: error.localizedDescription,
                        selectionRect: selectionRect,
                        onRetry: { [weak self] in
                            self?.retryAIAnalysis()
                        },
                        onClose: { [weak self] in
                            self?.aiAnalysisPreviewWindowService.dismiss()
                        }
                    )
                }
            }
            return
        } catch {
            await MainActor.run { [weak self] in
                guard let self, self.isAIAnalysisInProgress else { return }

                self.toastService.showToast(message: AppText.ocrFailedToast)
                self.aiAnalysisPreviewWindowService.presentError(
                    title: AppText.ocrFailedToast,
                    message: error.localizedDescription,
                    selectionRect: selectionRect,
                    onRetry: { [weak self] in
                        self?.retryAIAnalysis()
                    },
                    onClose: { [weak self] in
                        self?.aiAnalysisPreviewWindowService.dismiss()
                    }
                )
            }
            return
        }

        let trimmedText = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false else {
            await MainActor.run { [weak self] in
                guard let self, self.isAIAnalysisInProgress else { return }

                TYLogger.warn("Local OCR produced empty text", tag: "AI Analysis")
                self.toastService.showToast(message: self.emptyContentMessage(for: mode))
                self.aiAnalysisPreviewWindowService.dismiss()
            }
            return
        }

        TYLogger.info("Local OCR succeeded, text length: \(trimmedText.count)", tag: "AI Analysis")

        // Step 2: 构建完整 prompt — 将分析指令与提取的文字一起发给后端
        let analysisPrompt: String
        if let backendPrompt = mode.backendPrompt {
            let separator = AppText.aiAnalysisExtractedTextSeparator
            analysisPrompt = "\(backendPrompt)\n\n\(separator)\n\(trimmedText)"
        } else {
            analysisPrompt = trimmedText
        }

        // Step 3: 走后端文字分析接口
        do {
            let response = try await backendClient.analyzeText(
                requestID: requestID,
                prompt: analysisPrompt
            )

            let result = AIAnalysisResult(
                mode: mode,
                statusTitle: mode.resultStatusTitle,
                sections: [
                    AIAnalysisSection(title: mode.resultStatusTitle, content: response.analysis)
                ],
                rawText: response.analysis,
                secondaryCopyText: response.analysis
            )

            TYLogger.info("Text analysis succeeded, model: \(response.model)", tag: "AI Pro Backend")

            await MainActor.run { [weak self] in
                guard let self, self.isAIAnalysisInProgress else { return }

                self.aiAnalysisPreviewWindowService.presentResult(
                    result: result,
                    selectionRect: selectionRect,
                    onCopyAll: { [weak self] in
                        self?.copyAIAnalysisResult(result.formattedText)
                    },
                    onCopyNextSteps: { [weak self] in
                        self?.copyAIAnalysisSecondaryText(
                            result.secondaryCopyText,
                            successMessage: result.mode.secondaryCopySuccessMessage
                        )
                    },
                    onRetry: { [weak self] in
                        self?.retryAIAnalysis()
                    },
                    onClose: { [weak self] in
                        self?.aiAnalysisPreviewWindowService.dismiss()
                    }
                )
            }

        } catch let error as AIProBackendError {
            await MainActor.run { [weak self] in
                guard let self, self.isAIAnalysisInProgress else { return }

                switch error {
                case .authRequired, .subscriptionRequired:
                    TYLogger.warn("Backend rejected: \(error.localizedDescription)", tag: "AI Pro Backend")
                    self.toastService.showToast(message: error.localizedDescription)
                    self.aiAnalysisPreviewWindowService.presentError(
                        title: AppText.aiResultError,
                        message: error.localizedDescription,
                        selectionRect: selectionRect,
                        onRetry: { [weak self] in
                            self?.retryAIAnalysis()
                        },
                        onClose: { [weak self] in
                            self?.aiAnalysisPreviewWindowService.dismiss()
                        }
                    )
                default:
                    TYLogger.error("Backend error: \(error.localizedDescription)", tag: "AI Pro Backend")
                    self.toastService.showToast(message: error.localizedDescription)
                    self.aiAnalysisPreviewWindowService.presentError(
                        title: AppText.aiResultError,
                        message: error.localizedDescription,
                        selectionRect: selectionRect,
                        onRetry: { [weak self] in
                            self?.retryAIAnalysis()
                        },
                        onClose: { [weak self] in
                            self?.aiAnalysisPreviewWindowService.dismiss()
                        }
                    )
                }
            }
        } catch {
            await MainActor.run { [weak self] in
                guard let self, self.isAIAnalysisInProgress else { return }

                TYLogger.error("Unexpected error: \(error.localizedDescription)", tag: "AI Pro Backend")
                self.toastService.showToast(message: AppText.aiFailedToast)
                self.aiAnalysisPreviewWindowService.presentError(
                    title: AppText.aiResultError,
                    message: error.localizedDescription,
                    selectionRect: selectionRect,
                    onRetry: { [weak self] in
                        self?.retryAIAnalysis()
                    },
                    onClose: { [weak self] in
                        self?.aiAnalysisPreviewWindowService.dismiss()
                    }
                )
            }
        }
    }

    private func resolveAIText(
        from image: CGImage,
        strategy: AITextInputStrategy
    ) async throws -> String {
        switch strategy {
        case .localOCR:
            TYLogger.debug("Resolve text via local OCR", tag: "AI Analysis")
            return try ocrService.recognizeText(in: image)
        case .visionAI:
            TYLogger.debug("Resolve text via AI vision extraction", tag: "AI Analysis")
            let extracted = try await aiImageTextExtractionService.extractText(from: image)
            return extracted.text
        }
    }

    @MainActor
    private func handleVisionAIExtractionError(
        _ error: AIImageTextExtractionError,
        selectionRect: CGRect,
        mode: AIAnalysisMode,
        onRetry: @escaping () -> Void
    ) {
        switch error {
        case .noUsefulText:
            TYLogger.warn("Vision extraction produced no useful text", tag: "AI Analysis")
            toastService.showToast(message: emptyContentMessage(for: mode))
            aiAnalysisPreviewWindowService.dismiss()
        case .missingAPIKey, .imageEncodingFailed, .invalidResponse, .emptyOutput, .requestFailed:
            TYLogger.error("Vision extraction failed with recoverable error", tag: "AI Analysis")
            toastService.showToast(message: AppText.aiVisionFailedToast)
            aiAnalysisPreviewWindowService.presentError(
                title: AppText.aiVisionFailedToast,
                message: error.localizedDescription,
                selectionRect: selectionRect,
                onRetry: onRetry,
                onClose: { [weak self] in
                    self?.aiAnalysisPreviewWindowService.dismiss()
                }
            )
        }
    }

    @MainActor
    private func retryAIAnalysis() {
        guard let pendingCaptureSource,
              let pendingAIAnalysisMode else {
            return
        }

        let pendingSelectionRect = pendingCaptureSource.selectionRect
        guard isAIAnalysisInProgress == false else {
            return
        }

        isAIAnalysisInProgress = true
        overlayService.setAIButtonEnabled(false)
        aiAnalysisPreviewWindowService.presentLoading(
            selectionRect: pendingSelectionRect,
            message: pendingAIAnalysisMode.loadingMessage,
            onClose: { [weak self] in
                self?.aiAnalysisPreviewWindowService.dismiss()
            }
        )

        Task { [weak self] in
            guard let self else {
                return
            }

            await self.performAIAnalysis(for: pendingCaptureSource, mode: pendingAIAnalysisMode)
        }
    }

    private func performScrollingAIAnalysis(
        image: CGImage,
        selectionRect: CGRect,
        preferredSide: PreviewPlacementSide?,
        resultRevision: Int,
        requestID: UUID,
        mode: AIAnalysisMode
    ) async {
        let strategy = currentAITextInputStrategy()

        TYLogger.info("mode: \(mode.menuTitle)", tag: "AI Analysis")
        TYLogger.debug("strategy: \(strategy.logName)", tag: "AI Analysis")
        TYLogger.debug("resultRevision: \(resultRevision)", tag: "AI Analysis")
        TYLogger.debug("selection: \(Int(selectionRect.width))x\(Int(selectionRect.height))", tag: "AI Analysis")

        do {
            let text = try await resolveAIText(from: image, strategy: strategy)
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedText.isEmpty == false else {
                throw AIAnalysisError.emptyInput
            }

            let analysisPrompt: String
            if let backendPrompt = mode.backendPrompt {
                let separator = AppText.aiAnalysisExtractedTextSeparator
                analysisPrompt = "\(backendPrompt)\n\n\(separator)\n\(trimmedText)"
            } else {
                analysisPrompt = trimmedText
            }

            let response = try await AIProBackendClient().analyzeText(
                requestID: requestID.uuidString,
                prompt: analysisPrompt
            )
            let result = AIAnalysisResult(
                mode: mode,
                statusTitle: mode.resultStatusTitle,
                sections: [
                    AIAnalysisSection(title: mode.resultStatusTitle, content: response.analysis)
                ],
                rawText: response.analysis,
                secondaryCopyText: response.analysis
            )
            TYLogger.info("Scrolling text analysis succeeded, model: \(response.model)", tag: "AI Pro Backend")

            await MainActor.run {
                guard shouldAcceptScrollingAIResult(
                    requestID: requestID,
                    resultRevision: resultRevision
                ) else {
                    return
                }

                aiAnalysisPreviewWindowService.presentResult(
                    result: result,
                    selectionRect: selectionRect,
                    preferredSide: preferredSide,
                    onCopyAll: { [weak self] in
                        self?.copyAIAnalysisResult(result.formattedText)
                    },
                    onCopyNextSteps: { [weak self] in
                        self?.copyAIAnalysisSecondaryText(
                            result.secondaryCopyText,
                            successMessage: result.mode.secondaryCopySuccessMessage
                        )
                    },
                    onRetry: { [weak self] in
                        self?.retryScrollingAIAnalysis()
                    },
                    onClose: { [weak self] in
                        self?.aiAnalysisPreviewWindowService.dismiss()
                    }
                )
            }
        } catch let error as AIProBackendError {
            await MainActor.run {
                guard shouldAcceptScrollingAIResult(
                    requestID: requestID,
                    resultRevision: resultRevision
                ) else {
                    return
                }

                TYLogger.error("Scrolling backend error", tag: "AI Pro Backend", error: error)
                toastService.showToast(message: error.localizedDescription)
                aiAnalysisPreviewWindowService.presentError(
                    title: AppText.aiResultError,
                    message: error.localizedDescription,
                    selectionRect: selectionRect,
                    preferredSide: preferredSide,
                    onRetry: { [weak self] in
                        self?.retryScrollingAIAnalysis()
                    },
                    onClose: { [weak self] in
                        self?.aiAnalysisPreviewWindowService.dismiss()
                    }
                )
            }
        } catch let error as OCRError {
            await MainActor.run {
                guard shouldAcceptScrollingAIResult(
                    requestID: requestID,
                    resultRevision: resultRevision
                ) else {
                    return
                }

                switch error {
                case .noTextRecognized, .emptyText:
                    TYLogger.error("Scrolling local OCR produced no useful text", tag: "AI Analysis", error: error)
                    toastService.showToast(message: emptyContentMessage(for: mode))
                    aiAnalysisPreviewWindowService.dismiss()
                case .requestFailed:
                    toastService.showToast(message: AppText.ocrFailedToast)
                    aiAnalysisPreviewWindowService.presentError(
                        title: AppText.ocrFailedToast,
                        message: error.localizedDescription,
                        selectionRect: selectionRect,
                        preferredSide: preferredSide,
                        onRetry: { [weak self] in
                            self?.retryScrollingAIAnalysis()
                        },
                        onClose: { [weak self] in
                            self?.aiAnalysisPreviewWindowService.dismiss()
                        }
                    )
                }
            }
        } catch let error as AIImageTextExtractionError {
            await MainActor.run {
                guard shouldAcceptScrollingAIResult(
                    requestID: requestID,
                    resultRevision: resultRevision
                ) else {
                    return
                }

                switch error {
                case .noUsefulText:
                    TYLogger.warn("Scrolling vision extraction produced no useful text", tag: "AI Analysis")
                    toastService.showToast(message: emptyContentMessage(for: mode))
                    aiAnalysisPreviewWindowService.dismiss()
                case .missingAPIKey, .imageEncodingFailed, .invalidResponse, .emptyOutput, .requestFailed:
                    TYLogger.error("Scrolling vision extraction failed with recoverable error", tag: "AI Analysis")
                    toastService.showToast(message: AppText.aiVisionFailedToast)
                    aiAnalysisPreviewWindowService.presentError(
                        title: AppText.aiVisionFailedToast,
                        message: error.localizedDescription,
                        selectionRect: selectionRect,
                        preferredSide: preferredSide,
                        onRetry: { [weak self] in
                            self?.retryScrollingAIAnalysis()
                        },
                        onClose: { [weak self] in
                            self?.aiAnalysisPreviewWindowService.dismiss()
                        }
                    )
                }
            }
        } catch let error as AIAnalysisError {
            await MainActor.run {
                guard shouldAcceptScrollingAIResult(
                    requestID: requestID,
                    resultRevision: resultRevision
                ) else {
                    return
                }

                switch error {
                case .emptyInput, .lowQualityOutput:
                    TYLogger.error("Scrolling interface structure produced no useful content", tag: "AI Analysis", error: error)
                    toastService.showToast(message: emptyContentMessage(for: mode))
                    aiAnalysisPreviewWindowService.dismiss()
                case .missingAPIKey, .invalidResponse, .emptyOutput, .requestFailed:
                    toastService.showToast(message: AppText.aiFailedToast)
                    aiAnalysisPreviewWindowService.presentError(
                        title: AppText.aiResultError,
                        message: error.localizedDescription,
                        selectionRect: selectionRect,
                        preferredSide: preferredSide,
                        onRetry: { [weak self] in
                            self?.retryScrollingAIAnalysis()
                        },
                        onClose: { [weak self] in
                            self?.aiAnalysisPreviewWindowService.dismiss()
                        }
                    )
                }
            }
        } catch {
            await MainActor.run {
                guard shouldAcceptScrollingAIResult(
                    requestID: requestID,
                    resultRevision: resultRevision
                ) else {
                    return
                }
                toastService.showToast(message: AppText.aiFailedToast)
                aiAnalysisPreviewWindowService.presentError(
                    title: AppText.aiResultError,
                    message: error.localizedDescription,
                    selectionRect: selectionRect,
                    preferredSide: preferredSide,
                    onRetry: { [weak self] in
                        self?.retryScrollingAIAnalysis()
                    },
                    onClose: { [weak self] in
                        self?.aiAnalysisPreviewWindowService.dismiss()
                    }
                )
            }
        }
    }

    private func emptyContentMessage(for mode: AIAnalysisMode) -> String {
        switch mode {
        case .interfaceStructure:
            return AppText.aiNoValidContent
        default:
            return AppText.aiNoValidText
        }
    }

    @MainActor
    private func retryScrollingAIAnalysis() {
        guard isInScrollingCaptureMode,
              let pendingAIAnalysisMode else {
            return
        }

        analyzeScrollingCaptureResult(mode: pendingAIAnalysisMode)
    }

    @MainActor
    private func copyAIAnalysisResult(_ text: String) {
        do {
            try clipboardService.copyText(text)
            toastService.showToast(message: AppText.aiCopiedToast)
            aiAnalysisPreviewWindowService.dismiss()
        } catch {
            TYLogger.error("AI analysis clipboard copy failed", tag: "CaptureSession", error: error)
            toastService.showToast(message: AppText.aiCopyFailedToast)
        }
    }

    @MainActor
    private func copyAIAnalysisSecondaryText(
        _ text: String,
        successMessage: String
    ) {
        do {
            try clipboardService.copyText(text)
            toastService.showToast(message: successMessage)
            aiAnalysisPreviewWindowService.dismiss()
        } catch {
            TYLogger.error("AI secondary clipboard copy failed", tag: "CaptureSession", error: error)
            toastService.showToast(message: AppText.aiCopyFailedToast)
        }
    }

    @MainActor
    private func copyAIAnalysisNextSteps(_ text: String) {
        copyAIAnalysisSecondaryText(
            text,
            successMessage: AIAnalysisMode.developerError.secondaryCopySuccessMessage
        )
    }

    private func finishFailedSaveSession() {
        ocrPreviewWindowService.dismiss()
        aiAnalysisPreviewWindowService.dismiss()
        overlayService.dismissOverlay()
        scrollingCapturePanelService.dismissPanel()
        scrollingCapturePreviewWindowService.dismissPreview()
        clearPendingCapture()

        if state != .idle {
            transition(to: .idle)
        }
    }

    @MainActor
    private func presentSaveAlertIfNeeded(for error: ImageSaveError) {
        guard let alertContent = saveAlertContent(for: error) else {
            return
        }

        NSApplication.shared.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = alertContent.title
        alert.informativeText = alertContent.message
        alert.addButton(withTitle: AppText.openSettingsButton)
        alert.addButton(withTitle: AppText.cancelButton)

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return
        }

        openSettingsWindow()
    }

    private func saveAlertContent(for error: ImageSaveError) -> (title: String, message: String)? {
        switch error {
        case .saveDirectoryNotConfigured:
            return (
                title: AppText.saveDirNotConfiguredTitle,
                message: AppText.saveDirNotConfiguredMessage
            )
        case .directoryBookmarkResolutionFailed, .directoryBookmarkStale:
            return (
                title: AppText.saveDirAuthExpiredTitle,
                message: AppText.saveDirAuthExpiredMessage
            )
        case .directoryAccessFailed, .configuredDirectoryNotFound, .configuredPathIsNotDirectory:
            return (
                title: AppText.saveDirUnavailableTitle,
                message: AppText.saveDirUnavailableMessage
            )
        case .destinationCreationFailed, .finalizeFailed, .fileWriteFailed, .moveToConfiguredDirectoryFailed, .removeFailed:
            return nil
        }
    }

    @MainActor
    private func openSettingsWindow() {
        settingsOpenCoordinator.openSettings()
    }

    private func cancelScrollingCapture() {
        invalidateScrollingOCRRequest()
        scrollingAIRequestID = UUID()
        ocrPreviewWindowService.dismiss()
        aiAnalysisPreviewWindowService.dismiss()
        scrollingCapturePanelService.dismissPanel()
        scrollingCapturePreviewWindowService.dismissPreview()
        TYLogger.info("Scrolling Capture Cancelled", tag: "CaptureSession")
        overlayService.dismissOverlay()
        clearPendingCapture()
        if state != .idle {
            transition(to: .idle)
        }
    }

    @MainActor
    private func finishScrollingCaptureSession() {
        invalidateScrollingOCRRequest()
        scrollingAIRequestID = UUID()
        ocrPreviewWindowService.dismiss()
        aiAnalysisPreviewWindowService.dismiss()
        scrollingCapturePanelService.dismissPanel()
        scrollingCapturePreviewWindowService.dismissPreview()
        overlayService.dismissOverlay()
        clearPendingCapture()
        if state != .idle {
            transition(to: .idle)
        }
    }

    @MainActor
    private func failScrollingCapture(message: String, error: Error) {
        TYLogger.error(message, tag: "CaptureSession", error: error)
        invalidateScrollingOCRRequest()
        scrollingAIRequestID = UUID()
        ocrPreviewWindowService.dismiss()
        aiAnalysisPreviewWindowService.dismiss()
        scrollingCapturePanelService.dismissPanel()
        scrollingCapturePreviewWindowService.dismissPreview()
        scrollingCaptureFrames.removeAll()
        scrollingCaptureResultImage = nil
        isAppendingScrollingFrame = false
        removeScrollingEventMonitor()
        scrollingAppendTask?.cancel()
        scrollingAppendTask = nil
        isInScrollingCaptureMode = false
        overlayService.exitLongCaptureGuideMode()
        toastService.showToast(message: AppText.longScreenshotFailedToast)
    }

    private func reactivateSourceApplicationForScrolling() {
        guard let sourceApplication else {
            return
        }

        sourceApplication.activate(options: [])
    }

    private func preferredResultSideForScrollingPreview() -> PreviewPlacementSide? {
        guard let previewSide = scrollingCapturePreviewWindowService.attachmentSide,
              let selectionRect = pendingCaptureSource?.selectionRect,
              let screen = screenContaining(selectionRect) else {
            return nil
        }

        let visibleFrame = screen.visibleFrame
        let outerMargin: CGFloat = 24
        let gap: CGFloat = 20
        let minAIWindowWidth: CGFloat = 320
        let leftAvailableWidth = max(selectionRect.minX - visibleFrame.minX - gap - outerMargin, 0)
        let rightAvailableWidth = max(visibleFrame.maxX - selectionRect.maxX - gap - outerMargin, 0)

        let preferredSide = previewSide.opposite
        switch preferredSide {
        case .left:
            return leftAvailableWidth >= minAIWindowWidth ? .left : previewSide
        case .right:
            return rightAvailableWidth >= minAIWindowWidth ? .right : previewSide
        }
    }

    private func beginScrollingOCRRequest(for resultRevision: Int) -> Int {
        scrollingOCRRequestID &+= 1
        scrollingOCRTask?.cancel()
        scrollingOCRTask = nil
        scrollingOCRInFlightRevision = resultRevision
        return scrollingOCRRequestID
    }

    private func shouldAcceptScrollingOCRResult(
        requestID: Int,
        resultRevision: Int
    ) -> Bool {
        guard isInScrollingCaptureMode else {
            return false
        }

        guard scrollingOCRRequestID == requestID else {
            return false
        }

        guard scrollingCaptureResultRevision == resultRevision else {
            return false
        }

        return scrollingCaptureResultImage != nil
    }

    private func shouldAcceptScrollingAIResult(
        requestID: UUID,
        resultRevision: Int
    ) -> Bool {
        guard isInScrollingCaptureMode else {
            return false
        }

        guard scrollingAIRequestID == requestID else {
            return false
        }

        guard scrollingCaptureResultRevision == resultRevision else {
            return false
        }

        return scrollingCaptureResultImage != nil
    }

    private func finishScrollingOCRRequest(requestID: Int) {
        guard scrollingOCRRequestID == requestID else {
            return
        }

        scrollingOCRTask = nil
        scrollingOCRInFlightRevision = nil
    }

    private func invalidateScrollingOCRRequest() {
        scrollingOCRRequestID &+= 1
        scrollingOCRTask?.cancel()
        scrollingOCRTask = nil
        scrollingOCRInFlightRevision = nil
    }

    private func invalidateScrollingAIRequest() {
        scrollingAIRequestID = UUID()
    }

    private func captureInitialScrollingFrame(for selectionRect: CGRect) {
        appendScrollingCaptureFrameIfNeeded(for: selectionRect, requiresVisualChange: false)
    }

    private func appendScrollingCaptureFrameIfNeeded(
        for selectionRect: CGRect,
        requiresVisualChange: Bool = true
    ) {
        guard isAppendingScrollingFrame == false else {
            return
        }

        isAppendingScrollingFrame = true

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            defer {
                self.isAppendingScrollingFrame = false
            }

            do {
                let frame = try await self.screenCaptureService.captureImageExcludingCurrentApplication(in: selectionRect)

                if requiresVisualChange,
                   let previousFrame = self.scrollingCaptureFrames.last,
                   try self.scrollingCaptureService.hasVisualChange(between: previousFrame, and: frame) == false {
                    return
                }

                self.scrollingCaptureFrames.append(frame)
                try self.rebuildScrollingCaptureResult(for: selectionRect)
                TYLogger.debug("Scrolling Capture Frame Appended", tag: "CaptureSession")
                TYLogger.debug("count: \(self.scrollingCaptureFrames.count)", tag: "CaptureSession")
            } catch {
                TYLogger.error("Scrolling capture append failed", tag: "CaptureSession", error: error)
            }
        }
    }

    private func installScrollingEventMonitor(for selectionRect: CGRect) {
        removeScrollingEventMonitor()
        scrollingEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            guard let self else {
                return
            }

            if Thread.isMainThread {
                self.handleScrollingEvent(event, selectionRect: selectionRect)
                return
            }

            DispatchQueue.main.sync {
                self.handleScrollingEvent(event, selectionRect: selectionRect)
            }
        }
    }

    private func removeScrollingEventMonitor() {
        if let scrollingEventMonitor {
            NSEvent.removeMonitor(scrollingEventMonitor)
            self.scrollingEventMonitor = nil
        }
    }

    @MainActor
    private func handleScrollingEvent(_ event: NSEvent, selectionRect: CGRect) {
        guard isInScrollingCaptureMode else {
            return
        }

        guard event.scrollingDeltaY != 0 || event.scrollingDeltaX != 0 else {
            return
        }

        invalidateScrollingAIRequest()
        aiAnalysisPreviewWindowService.dismiss()
        scheduleScrollingAppend(for: selectionRect)
    }

    private func scheduleScrollingAppend(for selectionRect: CGRect) {
        scrollingAppendTask?.cancel()
        scrollingAppendTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)

            guard Task.isCancelled == false else {
                return
            }

            await MainActor.run {
                guard let self else {
                    return
                }

                guard self.isInScrollingCaptureMode else {
                    return
                }

                self.appendScrollingCaptureFrameIfNeeded(for: selectionRect, requiresVisualChange: true)
            }
        }
    }

    private func rebuildScrollingCaptureResult(for selectionRect: CGRect) throws {
        let image = try scrollingCaptureService.buildCurrentPreviewImage(from: scrollingCaptureFrames)
        invalidateScrollingOCRRequest()
        invalidateScrollingAIRequest()
        scrollingCaptureResultImage = image
        scrollingCaptureResultRevision &+= 1
        ocrPreviewWindowService.dismiss()
        aiAnalysisPreviewWindowService.dismiss()
        scrollingCapturePreviewWindowService.presentOrUpdatePreview(
            image: image,
            selectionRect: selectionRect,
            toolbarScreenRect: scrollingCapturePanelService.toolbarScreenFrame
        )
    }

    private func exportedImage(
        from image: CGImage,
        style: CapturePreviewStyle,
        annotations: [CaptureAnnotation],
        previewSize: CGSize
    ) throws -> CGImage {
        let shadowInset: CGFloat = style.showsShadow ? 24 : 0
        let imageRect = CGRect(
            x: shadowInset,
            y: shadowInset,
            width: CGFloat(image.width),
            height: CGFloat(image.height)
        )
        let canvasSize = CGSize(
            width: imageRect.width + (shadowInset * 2),
            height: imageRect.height + (shadowInset * 2)
        )

        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: Int(canvasSize.width),
                height: Int(canvasSize.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw ExportRenderError.contextCreationFailed
        }

        context.interpolationQuality = .high
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)

        let previewToImageScale = min(
            imageRect.width / max(previewSize.width, 1),
            imageRect.height / max(previewSize.height, 1)
        )
        let exportCornerRadius = min(
            style.cornerRadius * previewToImageScale,
            min(imageRect.width, imageRect.height) / 2
        )

        let path: CGPath
        if exportCornerRadius > 0 {
            path = CGPath(
                roundedRect: imageRect,
                cornerWidth: exportCornerRadius,
                cornerHeight: exportCornerRadius,
                transform: nil
            )
        } else {
            path = CGPath(rect: imageRect, transform: nil)
        }

        if style.showsShadow {
            context.saveGState()
            context.setShadow(
                offset: CGSize(width: 0, height: 0),
                blur: 18,
                color: CGColor(gray: 0, alpha: 0.28)
            )
            context.addPath(path)
            context.setFillColor(CGColor(gray: 0, alpha: 0.9))
            context.fillPath()
            context.restoreGState()
        }

        context.saveGState()
        context.addPath(path)
        context.clip()
        context.draw(image, in: imageRect)
        context.restoreGState()

        drawAnnotations(
            annotations,
            in: context,
            sourceImage: image,
            imageRect: imageRect,
            previewSize: previewSize
        )

        guard let renderedImage = context.makeImage() else {
            throw ExportRenderError.imageCreationFailed
        }

        return renderedImage
    }

    private func drawAnnotations(
        _ annotations: [CaptureAnnotation],
        in context: CGContext,
        sourceImage: CGImage,
        imageRect: CGRect,
        previewSize: CGSize
    ) {
        guard annotations.isEmpty == false else {
            return
        }
        guard previewSize.width > 0, previewSize.height > 0 else {
            return
        }

        context.saveGState()
        context.translateBy(x: imageRect.minX, y: imageRect.minY)
        context.scaleBy(
            x: imageRect.width / previewSize.width,
            y: imageRect.height / previewSize.height
        )

        for annotation in annotations {
            switch annotation {
            case let .rectangle(rect, props):
                let standardizedRect = rect.standardized
                let color = props.color.toNSColor().withAlphaComponent(props.opacity).cgColor

                if props.cornerRadius > 0 {
                    let path = CGPath(roundedRect: standardizedRect,
                                      cornerWidth: props.cornerRadius,
                                      cornerHeight: props.cornerRadius, transform: nil)
                    context.addPath(path)
                } else {
                    context.addRect(standardizedRect)
                }

                if props.isFilled {
                    context.setFillColor(color)
                    context.fillPath()
                } else {
                    context.setStrokeColor(color)
                    context.setLineWidth(props.lineWidth)
                    context.strokePath()
                }
            case let .ellipse(rect, props):
                context.setStrokeColor(props.color.toNSColor().withAlphaComponent(props.opacity).cgColor)
                context.setLineWidth(props.lineWidth)
                context.strokeEllipse(in: rect.standardized)
            case let .line(start, end, props):
                drawLine(from: start, to: end, properties: props, in: context)
            case let .arrow(start, end, props):
                drawArrow(from: start, to: end, properties: props, in: context)
            case let .pen(points, props):
                guard let first = points.first else {
                    continue
                }

                let path = NSBezierPath()
                path.lineWidth = props.lineWidth
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.move(to: first)
                for point in points.dropFirst() {
                    path.line(to: point)
                }

                if props.mode == .singleColor {
                    context.saveGState()
                    context.setStrokeColor(props.color.toNSColor().withAlphaComponent(props.opacity).cgColor)
                    context.addPath(path.cgPath)
                    context.strokePath()
                    context.restoreGState()
                } else {
                    drawEffectStroke(
                        path: path,
                        mode: props.mode,
                        sourceImage: sourceImage,
                        previewSize: previewSize,
                        in: context
                    )
                }
            case let .mosaic(rect, props):
                drawMosaic(
                    in: rect.standardized,
                    properties: props,
                    sourceImage: sourceImage,
                    previewSize: previewSize,
                    in: context
                )
            case let .text(value, origin, properties):
                drawText(value, at: origin, properties: properties, in: context)
            }
        }

        context.restoreGState()
    }

    private func drawLine(from start: CGPoint, to end: CGPoint, properties: ShapeStrokeProperties, in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(properties.color.toNSColor().withAlphaComponent(properties.opacity).cgColor)
        context.setLineWidth(properties.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.beginPath()
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        context.restoreGState()
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, properties: ArrowProperties, in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(properties.color.toNSColor().withAlphaComponent(properties.opacity).cgColor)
        context.setLineWidth(properties.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.beginPath()

        let arrowEnd: CGPoint
        let arrowAngle: CGFloat

        if properties.isCurved {
            let (control1, control2) = properties.effectiveControlPoints(from: start, to: end)
            context.move(to: start)
            context.addCurve(to: end, control1: control1, control2: control2)
            arrowEnd = end
            arrowAngle = atan2(end.y - control2.y, end.x - control2.x)
        } else {
            context.move(to: start)
            context.addLine(to: end)
            arrowEnd = end
            arrowAngle = atan2(end.y - start.y, end.x - start.x)
        }

        let arrowLength: CGFloat = 14
        let arrowSpread: CGFloat = .pi / 7

        let leftPoint = CGPoint(
            x: arrowEnd.x - cos(arrowAngle - arrowSpread) * arrowLength,
            y: arrowEnd.y - sin(arrowAngle - arrowSpread) * arrowLength
        )
        let rightPoint = CGPoint(
            x: arrowEnd.x - cos(arrowAngle + arrowSpread) * arrowLength,
            y: arrowEnd.y - sin(arrowAngle + arrowSpread) * arrowLength
        )

        context.move(to: arrowEnd)
        context.addLine(to: leftPoint)
        context.move(to: arrowEnd)
        context.addLine(to: rightPoint)
        context.strokePath()
        context.restoreGState()
    }

    private func drawText(_ text: String, at origin: CGPoint, properties: TextProperties, in context: CGContext) {
        let attributedString = NSAttributedString(string: text, attributes: properties.textAttributes)
        let line = CTLineCreateWithAttributedString(attributedString)

        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = origin
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private func drawMosaic(
        in rect: CGRect,
        properties: MosaicProperties,
        sourceImage: CGImage,
        previewSize: CGSize,
        in context: CGContext
    ) {
        guard rect.width > 0, rect.height > 0 else {
            return
        }

        guard let sourceRect = imageRect(for: rect, sourceImage: sourceImage, previewSize: previewSize) else {
            return
        }

        let fullImage = CIImage(cgImage: sourceImage)
        let outputImage: CIImage?

        switch properties.style {
        case .mosaic:
            let filter = CIFilter(name: "CIPixellate")
            filter?.setValue(fullImage, forKey: kCIInputImageKey)
            filter?.setValue(max(10, properties.size * 8), forKey: kCIInputScaleKey)
            outputImage = filter?.outputImage?.cropped(to: fullImage.extent)
        case .glass:
            let filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(fullImage, forKey: kCIInputImageKey)
            filter?.setValue(max(8, properties.size * 6), forKey: kCIInputRadiusKey)
            outputImage = filter?.outputImage?.cropped(to: fullImage.extent)
        }

        guard
            let outputImage,
            let outputCGImage = ciContext.createCGImage(outputImage, from: sourceRect)
        else {
            return
        }

        let clipPath = CGPath(
            roundedRect: rect,
            cornerWidth: CaptureAnnotation.mosaicCornerRadius,
            cornerHeight: CaptureAnnotation.mosaicCornerRadius,
            transform: nil
        )

        context.saveGState()
        context.addPath(clipPath)
        context.clip()
        context.draw(outputCGImage, in: rect)
        context.setFillColor(NSColor.white.withAlphaComponent(CaptureAnnotation.mosaicOverlayAlpha).cgColor)
        context.fill(rect)
        context.restoreGState()
    }

    private func drawEffectStroke(
        path: NSBezierPath,
        mode: PenMode,
        sourceImage: CGImage,
        previewSize: CGSize,
        in context: CGContext
    ) {
        let clipBounds = path.bounds.insetBy(dx: -20, dy: -20)
        guard clipBounds.width > 0, clipBounds.height > 0 else {
            return
        }

        guard let cropRect = imageRect(for: clipBounds, sourceImage: sourceImage, previewSize: previewSize) else {
            return
        }

        let inputImage = CIImage(cgImage: sourceImage).cropped(to: cropRect)
        let outputImage: CIImage?

        switch mode {
        case .gaussianBlur:
            let filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(inputImage, forKey: kCIInputImageKey)
            filter?.setValue(12, forKey: kCIInputRadiusKey)
            outputImage = filter?.outputImage?.cropped(to: cropRect)
        case .mosaic:
            let filter = CIFilter(name: "CIPixellate")
            filter?.setValue(inputImage, forKey: kCIInputImageKey)
            filter?.setValue(18, forKey: kCIInputScaleKey)
            outputImage = filter?.outputImage?.cropped(to: cropRect)
        case .singleColor:
            outputImage = nil
        }

        guard
            let outputImage,
            let outputCGImage = ciContext.createCGImage(outputImage, from: cropRect)
        else {
            return
        }

        context.saveGState()
        context.addPath(path.cgPath)
        context.clip()
        context.draw(outputCGImage, in: clipBounds)
        context.restoreGState()
    }

    private func imageRect(for previewRect: CGRect, sourceImage: CGImage, previewSize: CGSize) -> CGRect? {
        guard previewSize.width > 0, previewSize.height > 0 else {
            return nil
        }

        let imageScaleX = CGFloat(sourceImage.width) / previewSize.width
        let imageScaleY = CGFloat(sourceImage.height) / previewSize.height
        let sourceRect = CGRect(
            x: previewRect.minX * imageScaleX,
            y: previewRect.minY * imageScaleY,
            width: previewRect.width * imageScaleX,
            height: previewRect.height * imageScaleY
        ).integral

        guard sourceRect.width > 0, sourceRect.height > 0 else {
            return nil
        }

        return sourceRect
    }
}

enum ExportRenderError: LocalizedError {
    case contextCreationFailed
    case imageCreationFailed

    var errorDescription: String? {
        switch self {
        case .contextCreationFailed:
            return "Failed to create export render context."
        case .imageCreationFailed:
            return "Failed to create rendered export image."
        }
    }
}

enum FrozenCaptureExportError: LocalizedError {
    case selectionSpansMultipleDisplays
    case cachedScreenImageMissing

    var errorDescription: String? {
        switch self {
        case .selectionSpansMultipleDisplays:
            return "Frozen capture export only supports selections fully contained within a single display."
        case .cachedScreenImageMissing:
            return "Failed to locate the frozen screen image for the current selection."
        }
    }
}

private extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)

        for index in 0..<elementCount {
            switch element(at: index, associatedPoints: &points) {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }

        return path
    }
}
