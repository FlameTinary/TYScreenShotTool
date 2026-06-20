//
//  CaptureSessionService.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/5.
//

import AppKit
import CoreGraphics
import CoreImage
import Foundation

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

    private let overlayService: CaptureOverlayService
    private let screenCaptureService: ScreenCaptureService
    private let clipboardService: ClipboardService
    private let imageSaveService: ImageSaveService
    private let ocrService: OCRService
    private let aiAnalysisService: AIAnalysisService
    private let pinWindowService: PinWindowService
    private let toastService: ToastService
    private let settingsOpenCoordinator: SettingsOpenCoordinator
    private let scrollingCaptureService: ScrollingCaptureService
    private let scrollingCapturePanelService: ScrollingCapturePanelService
    private let scrollingCapturePreviewWindowService: ScrollingCapturePreviewWindowService
    private let ocrPreviewWindowService: OCRPreviewWindowService
    private let aiAnalysisPreviewWindowService: AIAnalysisPreviewWindowService
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

    init(
        overlayService: CaptureOverlayService,
        screenCaptureService: ScreenCaptureService,
        clipboardService: ClipboardService,
        imageSaveService: ImageSaveService,
        ocrService: OCRService,
        aiAnalysisService: AIAnalysisService,
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
        self.aiAnalysisService = aiAnalysisService
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
                print("Screen Recording permission required.")
                print("Please restart the app after granting permission.")
            } catch {
                print("Capture prepare failed: \(error.localizedDescription)")
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

    func completeSelection(_ rect: CGRect) {
        guard state == .dragging else {
            return
        }

        guard rect.width > 1, rect.height > 1 else {
            print("Capture skipped: invalid selection")
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

    func updatePendingSelection(_ rect: CGRect) {
        guard state == .selectionCompleted else {
            return
        }

        guard rect.width > 1, rect.height > 1 else {
            return
        }

        pendingCaptureSource = .frozenScreenRect(rect)
    }

    func cancelSession() {
        if isInScrollingCaptureMode {
            cancelScrollingCapture()
            return
        }

        guard state == .overlayPresented || state == .dragging || state == .selectionCompleted else {
            return
        }

        ocrPreviewWindowService.dismiss()
        aiAnalysisPreviewWindowService.dismiss()
        clearPendingCapture()
        overlayService.dismissOverlay()
        transition(to: .idle)
    }

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
                print("Clipboard Copy Success")
                await MainActor.run {
                    toastService.showToast(message: "已复制截图到剪贴板")
                    overlayService.dismissOverlay()
                }
                clearPendingCapture()
                transition(to: .idle)
            } catch ScreenCaptureError.invalidSelection {
                print("Capture skipped: invalid selection")
            } catch let error as ClipboardError {
                print("Clipboard copy failed: \(error.localizedDescription)")
            } catch {
                print("Clipboard copy failed: \(error.localizedDescription)")
            }
        }
    }

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
                print("Save Success")
                print("path: \(savedFileURL.path)")
                await MainActor.run {
                    toastService.showToast(message: "截图已保存")
                    overlayService.dismissOverlay()
                }
                clearPendingCapture()
                transition(to: .idle)
            } catch ScreenCaptureError.invalidSelection {
                print("Capture skipped: invalid selection")
            } catch let error as ImageSaveError {
                if let temporaryFileURL {
                    cleanupTemporaryImage(at: temporaryFileURL)
                }
                finishFailedSaveSession()
                print("Save failed: \(error.localizedDescription)")
                presentSaveAlertIfNeeded(for: error)
            } catch {
                if let temporaryFileURL {
                    cleanupTemporaryImage(at: temporaryFileURL)
                }
                finishFailedSaveSession()
                print("Save failed: \(error.localizedDescription)")
            }
        }
    }

    func ocrPendingCapture(style: CapturePreviewStyle, annotations: [CaptureAnnotation]) {
        guard state == .selectionCompleted, let pendingCaptureSource else {
            return
        }

        Task {
            do {
                let selectionRect = pendingCaptureSource.selectionRect
                let image = try await captureImageForPendingSource(pendingCaptureSource)
                let text = try ocrService.recognizeText(in: image)
                print("OCR Success")
                print("text: \(text)")
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
                print("OCR failed: \(error.localizedDescription)")
                await MainActor.run {
                    toastService.showToast(message: "OCR 识别失败")
                }
            }
        }
    }

    func analyzePendingCapture(style _: CapturePreviewStyle, annotations _: [CaptureAnnotation]) {
        guard state == .selectionCompleted, let pendingCaptureSource else {
            return
        }

        guard isAIAnalysisInProgress == false else {
            toastService.showToast(message: "AI 正在分析中")
            return
        }

        let selectionRect = pendingCaptureSource.selectionRect
        isAIAnalysisInProgress = true
        overlayService.setAIButtonEnabled(false)
        ocrPreviewWindowService.dismiss()
        aiAnalysisPreviewWindowService.presentLoading(
            selectionRect: selectionRect,
            onClose: { [weak self] in
                self?.aiAnalysisPreviewWindowService.dismiss()
            }
        )

        Task { [weak self] in
            guard let self else {
                return
            }

            await self.performAIAnalysis(for: pendingCaptureSource)
        }
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
                print("Pin Success")
                overlayService.dismissOverlay()
                clearPendingCapture()
                transition(to: .idle)
            } catch {
                print("Pin failed: \(error.localizedDescription)")
            }
        }
    }

    func startScrollingCapture(annotations: [CaptureAnnotation]) {
        guard state == .selectionCompleted, isInScrollingCaptureMode == false, let pendingCaptureSource else {
            return
        }

        let pendingSelectionRect = pendingCaptureSource.selectionRect

        guard annotations.isEmpty else {
            print("Scrolling capture failed: current selection contains annotations.")
            toastService.showToast(message: "长截图暂不支持标注后进入")
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
        pendingScreenImages.removeAll()
        reactivateSourceApplicationForScrolling()

        print("Scrolling Capture Started")

        captureInitialScrollingFrame(for: pendingSelectionRect)
        installScrollingEventMonitor(for: pendingSelectionRect)
    }

    func appendScrollingCaptureFrame() {
        guard isInScrollingCaptureMode, let pendingSelectionRect = pendingCaptureSource?.selectionRect else {
            return
        }

        appendScrollingCaptureFrameIfNeeded(for: pendingSelectionRect, requiresVisualChange: true)
    }

    func copyScrollingCaptureResult() {
        guard isInScrollingCaptureMode, let image = scrollingCaptureResultImage else {
            return
        }

        invalidateScrollingOCRRequest()

        do {
            try clipboardService.copyImage(image)
            print("Scrolling Capture Copy Success")
            toastService.showToast(message: "已复制长截图到剪贴板")
            finishScrollingCaptureSession()
        } catch {
            print("Scrolling capture copy failed: \(error.localizedDescription)")
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
                print("Scrolling Capture Save Success")
                print("path: \(savedFileURL.path)")
                self.toastService.showToast(message: "长截图已保存")
                self.finishScrollingCaptureSession()
            } catch let error as ImageSaveError {
                if let temporaryFileURL {
                    self.cleanupTemporaryImage(at: temporaryFileURL)
                }
                print("Scrolling capture save failed: \(error.localizedDescription)")
                self.presentSaveAlertIfNeeded(for: error)
            } catch {
                if let temporaryFileURL {
                    self.cleanupTemporaryImage(at: temporaryFileURL)
                }
                print("Scrolling capture save failed: \(error.localizedDescription)")
            }
        }
    }

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

        scrollingAIRequestID = UUID()
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
                    self.toastService.showToast(message: "OCR 识别失败")
                }
            }
        }
    }

    func analyzeScrollingCaptureResult() {
        guard isInScrollingCaptureMode,
              let image = scrollingCaptureResultImage,
              let selectionRect = pendingCaptureSource?.selectionRect else {
            return
        }

        invalidateScrollingOCRRequest()
        ocrPreviewWindowService.dismiss()
        let requestID = UUID()
        scrollingAIRequestID = requestID
        let preferredSide = preferredResultSideForScrollingPreview()

        aiAnalysisPreviewWindowService.presentLoading(
            selectionRect: selectionRect,
            preferredSide: preferredSide,
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
                requestID: requestID
            )
        }
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
        print("[CaptureSession] \(oldState.displayName) -> \(newState.displayName)")
    }

    private func logSelection(_ rect: CGRect) {
        print("Selection Rect")
        print("x: \(Int(rect.origin.x))")
        print("y: \(Int(rect.origin.y))")
        print("width: \(Int(rect.width))")
        print("height: \(Int(rect.height))")
    }

    private func clearPendingCapture() {
        pendingCaptureSource = nil
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
            print("Temporary image cleanup failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func copyOCRPreviewText(_ text: String) {
        do {
            try clipboardService.copyText(text)
            print("Clipboard Copy Success")
            toastService.showToast(message: "OCR 已复制到剪贴板")
            ocrPreviewWindowService.dismiss()
            overlayService.dismissOverlay()
            clearPendingCapture()
            transition(to: .idle)
        } catch {
            print("OCR clipboard copy failed: \(error.localizedDescription)")
            toastService.showToast(message: "OCR 复制失败")
        }
    }

    @MainActor
    private func copyScrollingOCRPreviewText(_ text: String) {
        do {
            try clipboardService.copyText(text)
            toastService.showToast(message: "OCR 已复制到剪贴板")
            ocrPreviewWindowService.dismiss()
        } catch {
            toastService.showToast(message: "OCR 复制失败")
        }
    }

    @MainActor
    private func performAIAnalysis(for source: PendingCaptureSource) async {
        let selectionRect = source.selectionRect

        defer {
            isAIAnalysisInProgress = false
            overlayService.setAIButtonEnabled(true)
        }

        do {
            let image = try await captureImageForPendingSource(source)
            let text = try ocrService.recognizeText(in: image)
            let result = try await aiAnalysisService.analyzeDeveloperError(text: text)

            aiAnalysisPreviewWindowService.presentResult(
                result: result,
                selectionRect: selectionRect,
                onCopyAll: { [weak self] in
                    self?.copyAIAnalysisResult(result.formattedText)
                },
                onCopyNextSteps: { [weak self] in
                    self?.copyAIAnalysisNextSteps(result.nextSteps)
                },
                onRetry: { [weak self] in
                    self?.retryAIAnalysis()
                },
                onClose: { [weak self] in
                    self?.aiAnalysisPreviewWindowService.dismiss()
                }
            )
        } catch let error as OCRError {
            toastService.showToast(message: "OCR 未识别到有效文本")
            aiAnalysisPreviewWindowService.presentError(
                message: error.localizedDescription,
                selectionRect: selectionRect,
                onRetry: { [weak self] in
                    self?.retryAIAnalysis()
                },
                onClose: { [weak self] in
                    self?.aiAnalysisPreviewWindowService.dismiss()
                }
            )
        } catch let error as AIAnalysisError {
            toastService.showToast(message: "AI 分析失败")
            aiAnalysisPreviewWindowService.presentError(
                message: error.localizedDescription,
                selectionRect: selectionRect,
                onRetry: { [weak self] in
                    self?.retryAIAnalysis()
                },
                onClose: { [weak self] in
                    self?.aiAnalysisPreviewWindowService.dismiss()
                }
            )
        } catch {
            toastService.showToast(message: "AI 分析失败")
            aiAnalysisPreviewWindowService.presentError(
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

    @MainActor
    private func retryAIAnalysis() {
        guard let pendingCaptureSource else {
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
            onClose: { [weak self] in
                self?.aiAnalysisPreviewWindowService.dismiss()
            }
        )

        Task { [weak self] in
            guard let self else {
                return
            }

            await self.performAIAnalysis(for: pendingCaptureSource)
        }
    }

    @MainActor
    private func performScrollingAIAnalysis(
        image: CGImage,
        selectionRect: CGRect,
        preferredSide: PreviewPlacementSide?,
        requestID: UUID
    ) async {
        do {
            let text = try ocrService.recognizeText(in: image)
            let result = try await aiAnalysisService.analyzeDeveloperError(text: text)
            guard requestID == scrollingAIRequestID, isInScrollingCaptureMode else {
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
                    self?.copyAIAnalysisNextSteps(result.nextSteps)
                },
                onRetry: { [weak self] in
                    self?.retryScrollingAIAnalysis()
                },
                onClose: { [weak self] in
                    self?.aiAnalysisPreviewWindowService.dismiss()
                }
            )
        } catch let error as OCRError {
            guard requestID == scrollingAIRequestID, isInScrollingCaptureMode else {
                return
            }
            toastService.showToast(message: "OCR 未识别到有效文本")
            aiAnalysisPreviewWindowService.presentError(
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
        } catch let error as AIAnalysisError {
            guard requestID == scrollingAIRequestID, isInScrollingCaptureMode else {
                return
            }
            toastService.showToast(message: "AI 分析失败")
            aiAnalysisPreviewWindowService.presentError(
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
        } catch {
            guard requestID == scrollingAIRequestID, isInScrollingCaptureMode else {
                return
            }
            toastService.showToast(message: "AI 分析失败")
            aiAnalysisPreviewWindowService.presentError(
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

    @MainActor
    private func retryScrollingAIAnalysis() {
        guard isInScrollingCaptureMode else {
            return
        }

        analyzeScrollingCaptureResult()
    }

    @MainActor
    private func copyAIAnalysisResult(_ text: String) {
        do {
            try clipboardService.copyText(text)
            toastService.showToast(message: "AI 分析结果已复制")
        } catch {
            print("AI analysis clipboard copy failed: \(error.localizedDescription)")
            toastService.showToast(message: "AI 结果复制失败")
        }
    }

    @MainActor
    private func copyAIAnalysisNextSteps(_ text: String) {
        do {
            try clipboardService.copyText(text)
            toastService.showToast(message: "建议下一步已复制")
        } catch {
            print("AI next steps clipboard copy failed: \(error.localizedDescription)")
            toastService.showToast(message: "建议复制失败")
        }
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
        alert.addButton(withTitle: "打开设置")
        alert.addButton(withTitle: "取消")

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
                title: "未配置保存目录",
                message: "请前往 Settings 选择截图 PNG 的保存目录，然后再执行保存。"
            )
        case .directoryBookmarkResolutionFailed, .directoryBookmarkStale:
            return (
                title: "保存目录授权已失效",
                message: "当前保存目录无法访问，请前往 Settings 重新选择保存目录。"
            )
        case .directoryAccessFailed, .configuredDirectoryNotFound, .configuredPathIsNotDirectory:
            return (
                title: "保存目录不可用",
                message: "当前保存目录无法访问，请前往 Settings 检查或重新选择保存目录。"
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
        print("Scrolling Capture Cancelled")
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
        print("\(message): \(error.localizedDescription)")
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
        toastService.showToast(message: "长截图失败，请调整滚动步进后重试")
    }

    private func reactivateSourceApplicationForScrolling() {
        guard let sourceApplication else {
            return
        }

        sourceApplication.activate(options: [])
    }

    private func preferredResultSideForScrollingPreview() -> PreviewPlacementSide? {
        scrollingCapturePreviewWindowService.attachmentSide?.opposite
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
                print("Scrolling Capture Frame Appended")
                print("count: \(self.scrollingCaptureFrames.count)")
            } catch {
                print("Scrolling capture append failed: \(error.localizedDescription)")
            }
        }
    }

    private func installScrollingEventMonitor(for selectionRect: CGRect) {
        removeScrollingEventMonitor()
        scrollingEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                guard self.isInScrollingCaptureMode else {
                    return
                }

                guard event.scrollingDeltaY != 0 || event.scrollingDeltaX != 0 else {
                    return
                }

                self.scheduleScrollingAppend(for: selectionRect)
            }
        }
    }

    private func removeScrollingEventMonitor() {
        if let scrollingEventMonitor {
            NSEvent.removeMonitor(scrollingEventMonitor)
            self.scrollingEventMonitor = nil
        }
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
        scrollingCaptureResultImage = image
        scrollingCaptureResultRevision &+= 1
        ocrPreviewWindowService.dismiss()
        scrollingCapturePreviewWindowService.presentOrUpdatePreview(image: image, selectionRect: selectionRect)
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
            case let .rectangle(rect):
                context.setStrokeColor(CaptureAnnotation.strokeColor)
                context.setLineWidth(CaptureAnnotation.lineWidth)
                context.stroke(rect.standardized)
            case let .ellipse(rect):
                context.setStrokeColor(CaptureAnnotation.strokeColor)
                context.setLineWidth(CaptureAnnotation.lineWidth)
                context.strokeEllipse(in: rect.standardized)
            case let .arrow(start, end):
                drawArrow(from: start, to: end, in: context)
            case let .pen(points):
                guard let first = points.first else {
                    continue
                }

                context.setStrokeColor(CaptureAnnotation.strokeColor)
                context.setLineWidth(CaptureAnnotation.lineWidth)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.beginPath()
                context.move(to: first)
                for point in points.dropFirst() {
                    context.addLine(to: point)
                }
                context.strokePath()
            case let .mosaic(rect):
                drawMosaic(in: rect.standardized, in: context)
            case let .text(value, origin):
                drawText(value, at: origin, in: context)
            }
        }

        context.restoreGState()
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, in context: CGContext) {
        context.setStrokeColor(CaptureAnnotation.strokeColor)
        context.setLineWidth(CaptureAnnotation.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.beginPath()
        context.move(to: start)
        context.addLine(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 14
        let arrowAngle: CGFloat = .pi / 7

        let leftPoint = CGPoint(
            x: end.x - cos(angle - arrowAngle) * arrowLength,
            y: end.y - sin(angle - arrowAngle) * arrowLength
        )
        let rightPoint = CGPoint(
            x: end.x - cos(angle + arrowAngle) * arrowLength,
            y: end.y - sin(angle + arrowAngle) * arrowLength
        )

        context.move(to: end)
        context.addLine(to: leftPoint)
        context.move(to: end)
        context.addLine(to: rightPoint)
        context.strokePath()
    }

    private func drawText(_ text: String, at origin: CGPoint, in context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: CaptureAnnotation.fontSize, weight: .semibold),
            .foregroundColor: NSColor(cgColor: CaptureAnnotation.strokeColor) ?? .systemRed
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)

        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = origin
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private func drawMosaic(in rect: CGRect, in context: CGContext) {
        guard rect.width > 0, rect.height > 0 else {
            return
        }

        let sourceRect = rect.integral
        guard sourceRect.width > 0, sourceRect.height > 0 else {
            return
        }

        guard let sourceImage = context.makeImage() else {
            return
        }

        let ciImage = CIImage(cgImage: sourceImage)

        guard
            let filter = CIFilter(name: "CIGaussianBlur"),
            let maskFilter = CIFilter(name: "CIBlendWithMask")
        else {
            return
        }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CaptureAnnotation.mosaicBlurRadius, forKey: kCIInputRadiusKey)

        guard let blurredImage = filter.outputImage?.cropped(to: ciImage.extent) else {
            return
        }

        let backgroundMask = CIImage(color: CIColor.black).cropped(to: ciImage.extent)
        let regionMask = CIImage(color: CIColor.white).cropped(to: sourceRect)
        let maskImage = regionMask.applyingFilter(
            "CISourceOverCompositing",
            parameters: [kCIInputBackgroundImageKey: backgroundMask]
        )

        maskFilter.setValue(blurredImage, forKey: kCIInputImageKey)
        maskFilter.setValue(ciImage, forKey: kCIInputBackgroundImageKey)
        maskFilter.setValue(maskImage, forKey: kCIInputMaskImageKey)

        guard
            let outputImage = maskFilter.outputImage,
            let outputCGImage = ciContext.createCGImage(outputImage, from: sourceRect)
        else {
            return
        }

        context.saveGState()
        context.draw(outputCGImage, in: sourceRect)
        context.restoreGState()
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
