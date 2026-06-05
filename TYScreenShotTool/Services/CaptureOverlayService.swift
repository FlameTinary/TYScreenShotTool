//
//  CaptureOverlayService.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/5.
//

import AppKit
import CoreGraphics

final class CaptureOverlayService {
    private var overlayWindows: [CaptureOverlayWindow] = []

    func presentOverlay() {
        guard overlayWindows.isEmpty else {
            return
        }

        for screen in NSScreen.screens {
            let overlayView = CaptureOverlayView(frame: screen.frame)
            overlayView.onCancel = { [weak self] in
                self?.dismissOverlay()
            }
            overlayView.onSelection = { [weak self] rect in
                self?.logSelection(rect)
                self?.dismissOverlay()
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

    private func logSelection(_ rect: CGRect) {
        print("Selection Rect")
        print("x: \(Int(rect.origin.x))")
        print("y: \(Int(rect.origin.y))")
        print("width: \(Int(rect.width))")
        print("height: \(Int(rect.height))")
    }
}
