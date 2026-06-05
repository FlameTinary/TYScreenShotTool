//
//  CaptureOverlayWindow.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/5.
//

import AppKit

final class CaptureOverlayWindow: NSWindow {
    init(screen: NSScreen, contentView: NSView) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        setFrame(screen.frame, display: false)
        self.contentView = contentView
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
    }

    func showOverlay() {
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)
    }
}
