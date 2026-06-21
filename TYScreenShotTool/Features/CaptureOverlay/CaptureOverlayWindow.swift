//
//  CaptureOverlayWindow.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/5.
//

import AppKit

/// 截图覆盖层窗口
///
/// 全屏无边框透明窗口，用于显示截图选区界面。
/// 窗口层级设置为 screenSaver，确保在最顶层显示。
final class CaptureOverlayWindow: NSWindow {
    /// 是否可以成为关键窗口
    override var canBecomeKey: Bool {
        true
    }

    /// 是否可以成为主窗口
    override var canBecomeMain: Bool {
        true
    }

    /// 初始化覆盖层窗口
    ///
    /// - Parameters:
    ///   - screen: 目标屏幕
    ///   - contentView: 窗口内容视图
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

    /// 显示覆盖层窗口
    ///
    /// 将窗口置于最前，设置十字光标，并使其成为关键窗口。
    func showOverlay() {
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)
        if let contentView {
            makeFirstResponder(contentView)
            invalidateCursorRects(for: contentView)
        }
        NSCursor.crosshair.set()
    }

    /// 设置鼠标穿透模式
    ///
    /// 在长截图模式下启用鼠标穿透，允许用户操作目标窗口。
    ///
    /// - Parameter enabled: 是否启用鼠标穿透
    func setMousePassthrough(_ enabled: Bool) {
        ignoresMouseEvents = enabled
    }
}
