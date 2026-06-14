//
//  PinWindowService.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/14.
//

import AppKit
import CoreGraphics

@MainActor
final class PinWindowService {
    private var pinnedWindow: NSWindow?
    private var pinnedImageView: NSImageView?

    func presentPinnedImage(_ image: CGImage) {
        let imageView = resolvedImageView()
        imageView.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))

        let window = resolvedWindow(with: imageView)
        let contentSize = NSSize(width: image.width, height: image.height)
        window.setContentSize(contentSize)
        window.minSize = contentSize
        window.maxSize = contentSize
        window.center()

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func resolvedWindow(with imageView: NSImageView) -> NSWindow {
        if let pinnedWindow {
            pinnedWindow.contentView = imageView
            return pinnedWindow
        }

        let window = NSPanel(
            contentRect: CGRect(origin: .zero, size: .zero),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "Pinned Capture"
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = imageView

        pinnedWindow = window
        return window
    }

    private func resolvedImageView() -> NSImageView {
        if let pinnedImageView {
            return pinnedImageView
        }

        let imageView = NSImageView(frame: .zero)
        imageView.imageScaling = .scaleNone
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.clear.cgColor
        pinnedImageView = imageView
        return imageView
    }
}
