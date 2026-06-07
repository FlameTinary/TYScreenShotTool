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
    private let settingsOpenCoordinator: SettingsOpenCoordinator
    private var state: CaptureState = .idle
    private var pendingSelectionRect: CGRect?

    init(
        overlayService: CaptureOverlayService,
        screenCaptureService: ScreenCaptureService,
        clipboardService: ClipboardService,
        imageSaveService: ImageSaveService,
        ocrService: OCRService,
        settingsOpenCoordinator: SettingsOpenCoordinator
    ) {
        self.overlayService = overlayService
        self.screenCaptureService = screenCaptureService
        self.clipboardService = clipboardService
        self.imageSaveService = imageSaveService
        self.ocrService = ocrService
        self.settingsOpenCoordinator = settingsOpenCoordinator
    }

    func startSession() {
        guard state == .idle else {
            return
        }

        transition(to: .overlayPresented)
        overlayService.presentOverlay()
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
        overlayService.showSelectionPreview(selectionRect: rect)
    }

    func cancelSession() {
        guard state == .overlayPresented || state == .dragging || state == .selectionCompleted else {
            return
        }

        clearPendingCapture()
        overlayService.dismissOverlay()
        transition(to: .idle)
    }

    func copyPendingCapture(style: CapturePreviewStyle) {
        guard state == .selectionCompleted, let pendingSelectionRect else {
            return
        }

        Task {
            do {
                overlayService.hideActiveOverlay()
                try await Task.sleep(nanoseconds: 120_000_000)
                let image = try await screenCaptureService.captureImage(in: pendingSelectionRect)
                let exportedImage = try exportedImage(from: image, style: style)
                try clipboardService.copyImage(exportedImage)
                print("Clipboard Copy Success")
                overlayService.dismissOverlay()
                clearPendingCapture()
                transition(to: .idle)
            } catch ScreenCaptureError.invalidSelection {
                overlayService.restoreActiveOverlay()
                print("Capture skipped: invalid selection")
            } catch ScreenCaptureError.permissionRequired {
                overlayService.restoreActiveOverlay()
                print("Screen Recording permission required.")
                print("Please restart the app after granting permission.")
            } catch let error as ClipboardError {
                overlayService.restoreActiveOverlay()
                print("Clipboard copy failed: \(error.localizedDescription)")
            } catch {
                overlayService.restoreActiveOverlay()
                print("Clipboard copy failed: \(error.localizedDescription)")
            }
        }
    }

    func savePendingCapture(style: CapturePreviewStyle) {
        guard state == .selectionCompleted, let pendingSelectionRect else {
            return
        }

        Task {
            var temporaryFileURL: URL?

            do {
                overlayService.hideActiveOverlay()
                try await Task.sleep(nanoseconds: 120_000_000)
                let image = try await screenCaptureService.captureImage(in: pendingSelectionRect)
                let exportedImage = try exportedImage(from: image, style: style)
                temporaryFileURL = try imageSaveService.saveTemporaryPNG(exportedImage)
                let savedFileURL = try imageSaveService.moveImageToConfiguredDirectory(from: temporaryFileURL!)
                print("Save Success")
                print("path: \(savedFileURL.path)")
                overlayService.dismissOverlay()
                clearPendingCapture()
                transition(to: .idle)
            } catch ScreenCaptureError.invalidSelection {
                overlayService.restoreActiveOverlay()
                print("Capture skipped: invalid selection")
            } catch ScreenCaptureError.permissionRequired {
                overlayService.restoreActiveOverlay()
                print("Screen Recording permission required.")
                print("Please restart the app after granting permission.")
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

    private func exportedImage(from image: CGImage, style: CapturePreviewStyle) throws -> CGImage {
        guard style.showsRoundedCorners || style.showsShadow else {
            return image
        }

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

        let path: CGPath
        if style.showsRoundedCorners {
            path = CGPath(
                roundedRect: imageRect,
                cornerWidth: 18,
                cornerHeight: 18,
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

        guard let renderedImage = context.makeImage() else {
            throw ExportRenderError.imageCreationFailed
        }

        return renderedImage
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
