//
//  PinWindowService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/14.
//

import AppKit
import CoreGraphics

/// 截图固定窗口服务
///
/// 提供将截图固定在屏幕上悬浮显示的功能，支持调整窗口大小和位置。
@MainActor
final class PinWindowService {
    private var pinnedWindow: NSWindow?
    private var pinnedImageView: NSImageView?
    private let defaultEdgeInset: CGFloat = 24
    private let minimumWindowSize = NSSize(width: 240, height: 160)
    private let maximumInitialWidth: CGFloat = 420
    private let maximumInitialHeight: CGFloat = 280

    /// 显示固定的截图图像
    ///
    /// 创建或更新悬浮窗口，显示指定的截图图像。
    /// 窗口位置基于截图来源区域自动计算。
    ///
    /// - Parameters:
    ///   - image: 要显示的截图图像
    ///   - sourceRect: 截图的来源区域，用于定位窗口
    func presentPinnedImage(_ image: CGImage, sourceRect: CGRect) {
        let imageView = resolvedImageView()
        imageView.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))

        let window = resolvedWindow(with: imageView)
        AppThemeCoordinator.shared.applyCurrentAppearance(to: window)
        let contentSize = fittedContentSize(for: image)
        window.setContentSize(contentSize)
        window.minSize = minimumWindowSize
        window.maxSize = NSSize(width: 1600, height: 1200)
        positionWindow(window, contentSize: contentSize, sourceRect: sourceRect)

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
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
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
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.clear.cgColor
        imageView.autoresizingMask = [.width, .height]
        pinnedImageView = imageView
        return imageView
    }

    private func fittedContentSize(for image: CGImage) -> NSSize {
        let originalWidth = CGFloat(image.width)
        let originalHeight = CGFloat(image.height)
        let widthScale = maximumInitialWidth / max(originalWidth, 1)
        let heightScale = maximumInitialHeight / max(originalHeight, 1)
        let scale = min(1, widthScale, heightScale)

        return NSSize(
            width: max(minimumWindowSize.width, floor(originalWidth * scale)),
            height: max(minimumWindowSize.height, floor(originalHeight * scale))
        )
    }

    private func positionWindow(_ window: NSWindow, contentSize: NSSize, sourceRect: CGRect) {
        let targetScreen = screen(containing: sourceRect) ?? NSScreen.main
        let visibleFrame = targetScreen?.visibleFrame ?? .zero
        let origin = CGPoint(
            x: visibleFrame.maxX - contentSize.width - defaultEdgeInset,
            y: visibleFrame.maxY - contentSize.height - defaultEdgeInset
        )
        window.setFrameOrigin(origin)
    }

    private func screen(containing rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.contains(CGPoint(x: rect.midX, y: rect.midY))
        }
    }
}
