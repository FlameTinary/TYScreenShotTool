//
//  ToastService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/14.
//

import AppKit
import Foundation

/// Toast 提示服务
///
/// 显示临时提示消息，自动在 1.6 秒后消失。
@MainActor
final class ToastService {
    private var toastWindow: NSWindow?
    private var messageLabel: NSTextField?
    private var dismissTask: Task<Void, Never>?

    func showToast(message: String) {
        let label = resolvedMessageLabel()
        label.stringValue = message
        label.sizeToFit()

        let paddingX: CGFloat = 14
        let paddingY: CGFloat = 10
        let contentSize = CGSize(
            width: label.frame.width + paddingX * 2,
            height: label.frame.height + paddingY * 2
        )

        let window = resolvedWindow(with: label)
        window.setContentSize(contentSize)

        if let screen = NSScreen.main?.visibleFrame {
            let origin = CGPoint(
                x: screen.midX - contentSize.width / 2,
                y: screen.minY + 72
            )
            window.setFrameOrigin(origin)
        }

        label.frame.origin = CGPoint(
            x: paddingX,
            y: paddingY
        )

        dismissTask?.cancel()
        window.alphaValue = 1
        window.orderFrontRegardless()

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard Task.isCancelled == false else {
                return
            }

            await MainActor.run {
                self?.toastWindow?.orderOut(nil)
            }
        }
    }

    private func resolvedWindow(with label: NSTextField) -> NSWindow {
        if let toastWindow {
            toastWindow.contentView?.subviews.forEach { $0.removeFromSuperview() }
            toastWindow.contentView?.addSubview(label)
            return toastWindow
        }

        let contentView = NSView(frame: .zero)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.82).cgColor
        contentView.layer?.cornerRadius = 12
        contentView.addSubview(label)

        let window = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 3)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = contentView

        toastWindow = window
        return window
    }

    private func resolvedMessageLabel() -> NSTextField {
        if let messageLabel {
            return messageLabel
        }

        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        messageLabel = label
        return label
    }
}
