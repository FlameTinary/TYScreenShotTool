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

    private var overlayWindows: [CaptureOverlayWindow] = []

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

            let window = CaptureOverlayWindow(screen: screen, contentView: overlayView)
            overlayWindows.append(window)
        }

        overlayWindows.forEach { $0.showOverlay() }
    }

    func dismissOverlay() {
        overlayWindows.forEach { window in
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
}
