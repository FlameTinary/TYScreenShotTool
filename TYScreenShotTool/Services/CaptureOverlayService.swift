//
//  CaptureOverlayService.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/5.
//

import AppKit
import CoreGraphics

final class CaptureOverlayService {
    var onCancel: (() -> Void)?
    var onDragStarted: (() -> Void)?
    var onSelectionCompleted: ((CGRect) -> Void)?
    var onCopyRequested: ((CapturePreviewStyle) -> Void)?
    var onSaveRequested: ((CapturePreviewStyle) -> Void)?

    private var overlayWindows: [CaptureOverlayWindow] = []
    private weak var activeOverlayView: CaptureOverlayView?
    private weak var activeOverlayWindow: CaptureOverlayWindow?

    func presentOverlay() {
        guard overlayWindows.isEmpty else {
            return
        }

        for screen in NSScreen.screens {
            let overlayView = CaptureOverlayView(frame: screen.frame)
            overlayView.onCancel = { [weak self] in
                self?.onCancel?()
            }
            overlayView.onDragStarted = { [weak self] in
                self?.onDragStarted?()
            }
            overlayView.onSelection = { [weak self] rect in
                guard let self, let window = overlayView.window else {
                    return
                }

                self.onSelectionCompleted?(window.convertToScreen(rect))
            }
            overlayView.onCopyRequested = { [weak self] in
                self?.onCopyRequested?($0)
            }
            overlayView.onSaveRequested = { [weak self] in
                self?.onSaveRequested?($0)
            }

            let window = CaptureOverlayWindow(screen: screen, contentView: overlayView)
            overlayWindows.append(window)
        }

        overlayWindows.forEach { $0.showOverlay() }
    }

    func showSelectionPreview(selectionRect: CGRect) {
        guard let activeScreen = screen(containing: selectionRect) else {
            return
        }

        for window in overlayWindows where window.screen != activeScreen {
            window.orderOut(nil)
        }

        overlayWindows.removeAll { $0.screen != activeScreen }

        guard let window = overlayWindows.first,
              let overlayView = window.contentView as? CaptureOverlayView else {
            return
        }

        activeOverlayWindow = window
        activeOverlayView = overlayView
        overlayView.showSelectionPreview(selectionRect: window.convertFromScreen(selectionRect))
        window.showOverlay()
    }

    func hideActiveOverlay() {
        activeOverlayWindow?.orderOut(nil)
    }

    func restoreActiveOverlay() {
        activeOverlayWindow?.showOverlay()
    }

    func dismissOverlay() {
        overlayWindows.forEach { window in
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        activeOverlayView = nil
        activeOverlayWindow = nil
    }

    private func screen(containing rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(CGPoint(x: rect.midX, y: rect.midY)) }
    }
}
