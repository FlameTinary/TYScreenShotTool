//
//  OCRPreviewWindowService.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/18.
//

import AppKit

@MainActor
final class OCRPreviewWindowService {
    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let containerView = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "OCR Result")
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let copyButton = NSButton(title: "复制", target: nil, action: nil)
    private let cancelButton = NSButton(title: "取消", target: nil, action: nil)
    private var onCopy: (() -> Void)?
    private var onCancel: (() -> Void)?

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

        cancelButton.target = self
        cancelButton.action = #selector(cancelRequested)
        cancelButton.bezelStyle = .rounded

        scrollView.documentView = textView
        panel.contentView = containerView
        containerView.addSubview(titleLabel)
        containerView.addSubview(scrollView)
        containerView.addSubview(copyButton)
        containerView.addSubview(cancelButton)
    }

    func present(
        text: String,
        selectionRect: CGRect,
        preferredSide: PreviewPlacementSide? = nil,
        onCopy: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        guard let screen = screenContaining(selectionRect) else {
            dismiss()
            return
        }

        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayText = normalizedText.isEmpty ? "未识别到文字" : text
        self.onCopy = onCopy
        self.onCancel = onCancel
        textView.string = displayText
        copyButton.isEnabled = normalizedText.isEmpty == false

        let panelFrame = frame(
            for: selectionRect,
            on: screen,
            preferredSide: preferredSide
        )
        panel.setFrame(panelFrame, display: true)
        layoutContent(in: panelFrame.size)
        panel.orderFrontRegardless()
    }

    func dismiss() {
        panel.orderOut(nil)
        textView.string = ""
        copyButton.isEnabled = true
        onCopy = nil
        onCancel = nil
    }

    @objc private func copyRequested() {
        onCopy?()
    }

    @objc private func cancelRequested() {
        onCancel?()
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

        cancelButton.frame = CGRect(
            x: size.width - padding - buttonWidth,
            y: padding,
            width: buttonWidth,
            height: buttonHeight
        )
        copyButton.frame = CGRect(
            x: cancelButton.frame.minX - spacing - buttonWidth,
            y: padding,
            width: buttonWidth,
            height: buttonHeight
        )

        let scrollTop = titleLabel.frame.minY - spacing
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

    private func frame(
        for selectionRect: CGRect,
        on screen: NSScreen,
        preferredSide: PreviewPlacementSide?
    ) -> CGRect {
        let visibleFrame = screen.visibleFrame
        let outerMargin: CGFloat = 24
        let gap: CGFloat = 20
        let minWidth: CGFloat = 260
        let maxWidth: CGFloat = 360
        let minHeight: CGFloat = 220
        let maxHeight: CGFloat = 420

        let leftAvailableWidth = selectionRect.minX - visibleFrame.minX - gap
        let rightAvailableWidth = visibleFrame.maxX - selectionRect.maxX - gap
        let defaultPlaceOnLeft = leftAvailableWidth >= rightAvailableWidth

        let preferredPlaceOnLeft: Bool?
        switch preferredSide {
        case .left:
            preferredPlaceOnLeft = true
        case .right:
            preferredPlaceOnLeft = false
        case nil:
            preferredPlaceOnLeft = nil
        }

        let placeOnLeft: Bool
        if let preferredPlaceOnLeft {
            let preferredWidth = preferredPlaceOnLeft ? leftAvailableWidth : rightAvailableWidth
            let oppositeWidth = preferredPlaceOnLeft ? rightAvailableWidth : leftAvailableWidth
            placeOnLeft = preferredWidth >= minWidth || preferredWidth >= oppositeWidth
        } else {
            placeOnLeft = defaultPlaceOnLeft
        }

        let chosenAvailableWidth = max(placeOnLeft ? leftAvailableWidth : rightAvailableWidth, 0)
        let availableWidth = max(chosenAvailableWidth - outerMargin, 0)
        let availableHeight = max(visibleFrame.height - outerMargin * 2, 0)

        let panelWidth = min(max(max(availableWidth, minWidth), minWidth), maxWidth)
        let panelHeight = min(max(max(availableHeight * 0.45, minHeight), minHeight), maxHeight)

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
