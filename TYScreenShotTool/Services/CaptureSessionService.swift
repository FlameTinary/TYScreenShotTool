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
    private let screenCaptureService: ScreenCaptureService
    private let imageSaveService: ImageSaveService
    private var state: CaptureState = .idle

    init(
        overlayService: CaptureOverlayService,
        screenCaptureService: ScreenCaptureService,
        imageSaveService: ImageSaveService
    ) {
        self.overlayService = overlayService
        self.screenCaptureService = screenCaptureService
        self.imageSaveService = imageSaveService
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
        overlayService.dismissOverlay()
        transition(to: .idle)

        Task {
            do {
                let image = try await screenCaptureService.captureImage(in: rect)
                let savedFileURL = try imageSaveService.savePNG(image)
                print("Save Success")
                print("path: \(savedFileURL.path)")
            } catch ScreenCaptureError.invalidSelection {
                print("Capture skipped: invalid selection")
            } catch ScreenCaptureError.permissionRequired {
                print("Screen Recording permission required.")
                print("Please restart the app after granting permission.")
            } catch let error as ImageSaveError {
                print("Save failed: \(error.localizedDescription)")
            } catch {
                print("Capture failed: \(error.localizedDescription)")
            }
        }
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
