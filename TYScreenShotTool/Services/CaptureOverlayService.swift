//
//  CaptureOverlayService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/5.
//

import AppKit
import CoreGraphics

final class CaptureOverlayService {
    var onCancel: (() -> Void)?
    var onDragStarted: (() -> Void)?
    var onSelectionCompleted: ((CGRect) -> Void)?
    var onWindowSelectionConfirmed: ((WindowSelectionCandidate) -> Void)?
    var onPreviewSelectionChanged: ((CGRect) -> Void)?
    var onCopyRequested: ((CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
    var onSaveRequested: ((CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
    var onOCRRequested: ((CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
    var onAIRequested: ((AIAnalysisMode, CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
    var onPinRequested: ((CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
    var onLongCaptureRequested: (([CaptureAnnotation]) -> Void)?
    var windowCandidateProvider: ((CGPoint) -> WindowSelectionCandidate?)?

    private var overlayWindows: [CaptureOverlayWindow] = []
    private weak var activeOverlayView: CaptureOverlayView?
    private weak var activeOverlayWindow: CaptureOverlayWindow?

    func presentOverlay(screenImages: [CGDirectDisplayID: CGImage]) {
        guard overlayWindows.isEmpty else {
            return
        }

        for screen in NSScreen.screens {
            let overlayView = CaptureOverlayView(frame: screen.frame)
            if let displayID = try? displayID(for: screen) {
                overlayView.selectionSourceScreenImage = screenImages[displayID]
            }
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
            overlayView.windowCandidateProvider = { [weak self] localPoint in
                guard let self, let window = overlayView.window else {
                    return nil
                }

                let screenPoint = window.convertToScreen(CGRect(origin: localPoint, size: .zero)).origin
                guard let candidate = self.windowCandidateProvider?(screenPoint) else {
                    return nil
                }

                return WindowSelectionCandidate(
                    frame: window.convertFromScreen(candidate.frame),
                    ownerName: candidate.ownerName,
                    windowID: candidate.windowID
                )
            }
            overlayView.onWindowSelectionConfirmed = { [weak self] candidate in
                guard let self, let window = overlayView.window else {
                    return
                }

                self.onWindowSelectionConfirmed?(
                    WindowSelectionCandidate(
                        frame: window.convertToScreen(candidate.frame),
                        ownerName: candidate.ownerName,
                        windowID: candidate.windowID
                    )
                )
            }
            overlayView.onPreviewSelectionChanged = { [weak self] rect in
                guard let self, let window = overlayView.window else {
                    return
                }

                self.onPreviewSelectionChanged?(window.convertToScreen(rect))
            }
            overlayView.onCopyRequested = { [weak self] in
                self?.onCopyRequested?($0, $1)
            }
            overlayView.onSaveRequested = { [weak self] in
                self?.onSaveRequested?($0, $1)
            }
            overlayView.onOCRRequested = { [weak self] in
                self?.onOCRRequested?($0, $1)
            }
            overlayView.onAIRequested = { [weak self] mode, style, annotations in
                self?.onAIRequested?(mode, style, annotations)
            }
            overlayView.onPinRequested = { [weak self] in
                self?.onPinRequested?($0, $1)
            }
            overlayView.onLongCaptureRequested = { [weak self] annotations in
                self?.onLongCaptureRequested?(annotations)
            }

            let window = CaptureOverlayWindow(screen: screen, contentView: overlayView)
            overlayWindows.append(window)
        }

        overlayWindows.forEach { $0.showOverlay() }
    }

    func showSelectionPreview(selectionRect: CGRect, screenImages: [CGDirectDisplayID: CGImage]) {
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
        let displayID = try? displayID(for: activeScreen)
        overlayView.showSelectionPreview(
            selectionRect: window.convertFromScreen(selectionRect),
            sourceScreenImage: displayID.flatMap { screenImages[$0] },
            screenFrame: activeScreen.frame
        )
        window.showOverlay()
    }

    func hideActiveOverlay() {
        activeOverlayWindow?.orderOut(nil)
    }

    func restoreActiveOverlay() {
        activeOverlayWindow?.showOverlay()
    }

    func setAIButtonEnabled(_ isEnabled: Bool) {
        activeOverlayView?.setAIButtonEnabled(isEnabled)
    }

    func enterLongCaptureGuideMode() {
        activeOverlayView?.enterLongCaptureGuideMode()
        activeOverlayWindow?.setMousePassthrough(true)
        activeOverlayWindow?.orderFrontRegardless()
    }

    func exitLongCaptureGuideMode() {
        activeOverlayWindow?.setMousePassthrough(false)
        activeOverlayView?.exitLongCaptureGuideMode()
        activeOverlayWindow?.showOverlay()
    }

    func dismissOverlay() {
        overlayWindows.forEach { window in
            window.setMousePassthrough(false)
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        activeOverlayView = nil
        activeOverlayWindow = nil
    }

    private func screen(containing rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(CGPoint(x: rect.midX, y: rect.midY)) }
    }

    private func displayID(for screen: NSScreen) throws -> CGDirectDisplayID {
        guard
            let value = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            throw ScreenCaptureError.displayNotFound
        }

        return CGDirectDisplayID(value.uint32Value)
    }
}
