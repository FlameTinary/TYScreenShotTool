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
    private let overlayService: CaptureOverlayService
    private let screenCaptureService: ScreenCaptureService
    private let clipboardService: ClipboardService
    private let imageSaveService: ImageSaveService
    private let ocrService: OCRService
    private let pinWindowService: PinWindowService
    private let toastService: ToastService
    private let settingsOpenCoordinator: SettingsOpenCoordinator
    private let ciContext = CIContext()
    private var state: CaptureState = .idle
    private var pendingSelectionRect: CGRect?
    private var pendingScreenImages: [CGDirectDisplayID: CGImage] = [:]
    private var isPreparingSession = false

    init(
        overlayService: CaptureOverlayService,
        screenCaptureService: ScreenCaptureService,
        clipboardService: ClipboardService,
        imageSaveService: ImageSaveService,
        ocrService: OCRService,
        pinWindowService: PinWindowService,
        toastService: ToastService,
        settingsOpenCoordinator: SettingsOpenCoordinator
    ) {
        self.overlayService = overlayService
        self.screenCaptureService = screenCaptureService
        self.clipboardService = clipboardService
        self.imageSaveService = imageSaveService
        self.ocrService = ocrService
        self.pinWindowService = pinWindowService
        self.toastService = toastService
        self.settingsOpenCoordinator = settingsOpenCoordinator
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
        pendingSelectionRect = rect
        overlayService.showSelectionPreview(selectionRect: rect, screenImages: pendingScreenImages)
    }

    func updatePendingSelection(_ rect: CGRect) {
        guard state == .selectionCompleted else {
            return
        }

        guard rect.width > 1, rect.height > 1 else {
            return
        }

        pendingSelectionRect = rect
    }

    func cancelSession() {
        guard state == .overlayPresented || state == .dragging || state == .selectionCompleted else {
            return
        }

        clearPendingCapture()
        overlayService.dismissOverlay()
        transition(to: .idle)
    }

    func copyPendingCapture(style: CapturePreviewStyle, annotations: [CaptureAnnotation]) {
        guard state == .selectionCompleted, let pendingSelectionRect else {
            return
        }

        Task {
            do {
                let image = try frozenSelectionImage(for: pendingSelectionRect)
                let exportedImage = try exportedImage(
                    from: image,
                    style: style,
                    annotations: annotations,
                    previewSize: pendingSelectionRect.size
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
        guard state == .selectionCompleted, let pendingSelectionRect else {
            return
        }

        Task {
            var temporaryFileURL: URL?

            do {
                let image = try frozenSelectionImage(for: pendingSelectionRect)
                let exportedImage = try exportedImage(
                    from: image,
                    style: style,
                    annotations: annotations,
                    previewSize: pendingSelectionRect.size
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
        guard state == .selectionCompleted, let pendingSelectionRect else {
            return
        }

        Task {
            do {
                let image = try frozenSelectionImage(for: pendingSelectionRect)
                let text = try ocrService.recognizeText(in: image)
                try clipboardService.copyText(text)
                print("OCR Success")
                print("text: \(text)")
                print("Clipboard Copy Success")
                await MainActor.run {
                    toastService.showToast(message: "OCR 已复制到剪贴板")
                    overlayService.dismissOverlay()
                }
                clearPendingCapture()
                transition(to: .idle)
            } catch {
                print("OCR failed: \(error.localizedDescription)")
            }
        }
    }

    func pinPendingCapture(style: CapturePreviewStyle, annotations: [CaptureAnnotation]) {
        guard state == .selectionCompleted, let pendingSelectionRect else {
            return
        }

        Task { @MainActor in
            do {
                let exportedImage = try prepareExportedImage(
                    selectionRect: pendingSelectionRect,
                    style: style,
                    annotations: annotations
                )
                pinWindowService.presentPinnedImage(exportedImage, sourceRect: pendingSelectionRect)
                print("Pin Success")
                overlayService.dismissOverlay()
                clearPendingCapture()
                transition(to: .idle)
            } catch {
                print("Pin failed: \(error.localizedDescription)")
            }
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

    private func prepareExportedImage(
        selectionRect: CGRect,
        style: CapturePreviewStyle,
        annotations: [CaptureAnnotation]
    ) throws -> CGImage {
        let image = try frozenSelectionImage(for: selectionRect)
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
        pendingSelectionRect = nil
        pendingScreenImages.removeAll()
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

    private func finishFailedSaveSession() {
        overlayService.dismissOverlay()
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
