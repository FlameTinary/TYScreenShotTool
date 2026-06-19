//
//  AIAnalysisPreviewWindowService.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/18.
//

import AppKit

@MainActor
final class AIAnalysisPreviewWindowService {
    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let containerView = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "AI 分析")
    private let statusLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let copyButton = NSButton(title: "复制", target: nil, action: nil)
    private let retryButton = NSButton(title: "重试", target: nil, action: nil)
    private let closeButton = NSButton(title: "关闭", target: nil, action: nil)

    private var onCopy: (() -> Void)?
    private var onRetry: (() -> Void)?
    private var onClose: (() -> Void)?

    init() {
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        containerView.material = .hudWindow
        containerView.blendingMode = .withinWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 14
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor

        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white

        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = NSColor.white.withAlphaComponent(0.82)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = .white
        textView.font = .systemFont(ofSize: 13)
        textView.textContainerInset = CGSize(width: 8, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
        textView.autoresizingMask = [.width]

        copyButton.target = self
        copyButton.action = #selector(copyRequested)
        copyButton.bezelStyle = .rounded

        retryButton.target = self
        retryButton.action = #selector(retryRequested)
        retryButton.bezelStyle = .rounded

        closeButton.target = self
        closeButton.action = #selector(closeRequested)
        closeButton.bezelStyle = .rounded

        scrollView.documentView = textView
        panel.contentView = containerView
        containerView.addSubview(titleLabel)
        containerView.addSubview(statusLabel)
        containerView.addSubview(scrollView)
        containerView.addSubview(copyButton)
        containerView.addSubview(retryButton)
        containerView.addSubview(closeButton)
    }

    func presentLoading(
        selectionRect: CGRect,
        message: String = "AI 正在分析...",
        onClose: @escaping () -> Void
    ) {
        statusLabel.stringValue = message
        textView.string = ""
        copyButton.isEnabled = false
        retryButton.isEnabled = false
        onCopy = nil
        onRetry = nil
        self.onClose = onClose
        presentPanel(selectionRect: selectionRect)
    }

    func presentResult(
        text: String,
        selectionRect: CGRect,
        onCopy: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        statusLabel.stringValue = "AI 分析结果"
        textView.string = text
        copyButton.isEnabled = true
        retryButton.isEnabled = true
        self.onCopy = onCopy
        self.onRetry = onRetry
        self.onClose = onClose
        presentPanel(selectionRect: selectionRect)
    }

    func presentError(
        message: String,
        selectionRect: CGRect,
        onRetry: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        statusLabel.stringValue = "AI 分析失败"
        textView.string = message
        copyButton.isEnabled = false
        retryButton.isEnabled = true
        onCopy = nil
        self.onRetry = onRetry
        self.onClose = onClose
        presentPanel(selectionRect: selectionRect)
    }

    func dismiss() {
        panel.orderOut(nil)
        textView.string = ""
        copyButton.isEnabled = true
        retryButton.isEnabled = true
        onCopy = nil
        onRetry = nil
        onClose = nil
    }

    @objc private func copyRequested() {
        onCopy?()
    }

    @objc private func retryRequested() {
        onRetry?()
    }

    @objc private func closeRequested() {
        onClose?()
    }

    private func presentPanel(selectionRect: CGRect) {
        guard let screen = screenContaining(selectionRect) else {
            dismiss()
            return
        }

        let panelFrame = frame(for: selectionRect, on: screen)
        panel.setFrame(panelFrame, display: true)
        layoutContent(in: panelFrame.size)
        panel.orderFrontRegardless()
    }

    private func layoutContent(in size: CGSize) {
        containerView.frame = CGRect(origin: .zero, size: size)

        let padding: CGFloat = 14
        let buttonHeight: CGFloat = 28
        let buttonWidth: CGFloat = 72
        let spacing: CGFloat = 10

        titleLabel.sizeToFit()
        titleLabel.frame.origin = CGPoint(
            x: padding,
            y: size.height - padding - titleLabel.frame.height
        )

        statusLabel.sizeToFit()
        statusLabel.frame.origin = CGPoint(
            x: padding,
            y: titleLabel.frame.minY - spacing - statusLabel.frame.height
        )

        closeButton.frame = CGRect(
            x: size.width - padding - buttonWidth,
            y: padding,
            width: buttonWidth,
            height: buttonHeight
        )
        retryButton.frame = CGRect(
            x: closeButton.frame.minX - spacing - buttonWidth,
            y: padding,
            width: buttonWidth,
            height: buttonHeight
        )
        copyButton.frame = CGRect(
            x: retryButton.frame.minX - spacing - buttonWidth,
            y: padding,
            width: buttonWidth,
            height: buttonHeight
        )

        let scrollTop = statusLabel.frame.minY - spacing
        let scrollBottom = copyButton.frame.maxY + spacing
        scrollView.frame = CGRect(
            x: padding,
            y: scrollBottom,
            width: size.width - padding * 2,
            height: max(scrollTop - scrollBottom, 80)
        )

        textView.minSize = CGSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = CGSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.frame = CGRect(origin: .zero, size: scrollView.contentSize)
        textView.textContainer?.containerSize = CGSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
    }

    private func frame(for selectionRect: CGRect, on screen: NSScreen) -> CGRect {
        let visibleFrame = screen.visibleFrame
        let outerMargin: CGFloat = 24
        let gap: CGFloat = 20
        let minWidth: CGFloat = 300
        let maxWidth: CGFloat = 400
        let minHeight: CGFloat = 240
        let maxHeight: CGFloat = 460

        let leftAvailableWidth = selectionRect.minX - visibleFrame.minX - gap
        let rightAvailableWidth = visibleFrame.maxX - selectionRect.maxX - gap
        let placeOnLeft = leftAvailableWidth >= rightAvailableWidth
        let chosenAvailableWidth = max(placeOnLeft ? leftAvailableWidth : rightAvailableWidth, 0)
        let availableWidth = max(chosenAvailableWidth - outerMargin, 0)
        let availableHeight = max(visibleFrame.height - outerMargin * 2, 0)

        let panelWidth = min(max(max(availableWidth, minWidth), minWidth), maxWidth)
        let panelHeight = min(max(max(availableHeight * 0.48, minHeight), minHeight), maxHeight)

        let panelX: CGFloat
        if placeOnLeft {
            panelX = max(
                visibleFrame.minX + outerMargin,
                selectionRect.minX - gap - panelWidth
            )
        } else {
            panelX = min(
                visibleFrame.maxX - outerMargin - panelWidth,
                selectionRect.maxX + gap
            )
        }

        let panelY = min(
            max(selectionRect.midY - panelHeight / 2, visibleFrame.minY + outerMargin),
            visibleFrame.maxY - outerMargin - panelHeight
        )

        return CGRect(
            x: panelX,
            y: panelY,
            width: panelWidth,
            height: panelHeight
        )
    }

    private func screenContaining(_ rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.contains(CGPoint(x: rect.midX, y: rect.midY))
        }
    }
}
