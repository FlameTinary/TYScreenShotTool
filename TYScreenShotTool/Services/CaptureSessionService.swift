//
//  CaptureSessionService.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/5.
//

import CoreGraphics
import Foundation

final class CaptureSessionService {
    private let overlayService: CaptureOverlayService
    private var state: CaptureState = .idle

    init(overlayService: CaptureOverlayService) {
        self.overlayService = overlayService
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

        transition(to: .selectionCompleted)
        logSelection(rect)
        overlayService.dismissOverlay()
        transition(to: .idle)
    }

    func cancelSession() {
        guard state == .overlayPresented || state == .dragging else {
            return
        }

        overlayService.dismissOverlay()
        transition(to: .idle)
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
}
