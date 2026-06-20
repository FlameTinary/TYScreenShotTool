//
//  AIAnalysisPreviewWindowService.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/18.
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
    private let documentContentView = FlippedContentView()
    private let summarySectionView = SectionView(title: "报错大意")
    private let causesSectionView = SectionView(title: "可能原因")
    private let nextStepsSectionView = SectionView(title: "建议下一步")
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let copyAllButton = NSButton(title: "复制全部", target: nil, action: nil)
    private let copyNextStepsButton = NSButton(title: "复制建议", target: nil, action: nil)
    private let retryButton = NSButton(title: "重试", target: nil, action: nil)
    private let closeButton = NSButton(title: "关闭", target: nil, action: nil)

    private var onCopyAll: (() -> Void)?
    private var onCopyNextSteps: (() -> Void)?
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
        documentContentView.wantsLayer = false

        messageLabel.font = .systemFont(ofSize: 13)
        messageLabel.textColor = .white
        messageLabel.maximumNumberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.isHidden = true

        [copyAllButton, copyNextStepsButton, retryButton, closeButton].forEach {
            $0.target = self
            $0.bezelStyle = .rounded
        }

        copyAllButton.action = #selector(copyAllRequested)
        copyNextStepsButton.action = #selector(copyNextStepsRequested)
        retryButton.action = #selector(retryRequested)
        closeButton.action = #selector(closeRequested)

        scrollView.documentView = documentContentView
        panel.contentView = containerView
        containerView.addSubview(titleLabel)
        containerView.addSubview(statusLabel)
        containerView.addSubview(scrollView)
        containerView.addSubview(copyAllButton)
        containerView.addSubview(copyNextStepsButton)
        containerView.addSubview(retryButton)
        containerView.addSubview(closeButton)

        documentContentView.addSubview(summarySectionView)
        documentContentView.addSubview(causesSectionView)
        documentContentView.addSubview(nextStepsSectionView)
        documentContentView.addSubview(messageLabel)
    }

    func presentLoading(
        selectionRect: CGRect,
        preferredSide: PreviewPlacementSide? = nil,
        message: String = "AI 正在分析...",
        onClose: @escaping () -> Void
    ) {
        statusLabel.stringValue = message
        messageLabel.stringValue = ""
        configureForLoadingOrError(messageVisible: false)
        copyAllButton.isEnabled = false
        copyNextStepsButton.isEnabled = false
        retryButton.isEnabled = false
        onCopyAll = nil
        onCopyNextSteps = nil
        onRetry = nil
        self.onClose = onClose
        presentPanel(
            selectionRect: selectionRect,
            preferredSide: preferredSide
        )
    }

    func presentResult(
        result: AIAnalysisResult,
        selectionRect: CGRect,
        preferredSide: PreviewPlacementSide? = nil,
        onCopyAll: @escaping () -> Void,
        onCopyNextSteps: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        statusLabel.stringValue = "AI 分析结果"
        configureForResult(result)
        copyAllButton.isEnabled = true
        copyNextStepsButton.isEnabled = true
        retryButton.isEnabled = true
        self.onCopyAll = onCopyAll
        self.onCopyNextSteps = onCopyNextSteps
        self.onRetry = onRetry
        self.onClose = onClose
        presentPanel(
            selectionRect: selectionRect,
            preferredSide: preferredSide
        )
    }

    func presentError(
        message: String,
        selectionRect: CGRect,
        preferredSide: PreviewPlacementSide? = nil,
        onRetry: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        statusLabel.stringValue = "AI 分析失败"
        messageLabel.stringValue = message
        configureForLoadingOrError(messageVisible: true)
        copyAllButton.isEnabled = false
        copyNextStepsButton.isEnabled = false
        retryButton.isEnabled = true
        onCopyAll = nil
        onCopyNextSteps = nil
        self.onRetry = onRetry
        self.onClose = onClose
        presentPanel(
            selectionRect: selectionRect,
            preferredSide: preferredSide
        )
    }

    func dismiss() {
        panel.orderOut(nil)
        onCopyAll = nil
        onCopyNextSteps = nil
        onRetry = nil
        onClose = nil
        copyAllButton.isEnabled = true
        copyNextStepsButton.isEnabled = true
        retryButton.isEnabled = true
    }

    @objc private func copyAllRequested() {
        onCopyAll?()
    }

    @objc private func copyNextStepsRequested() {
        onCopyNextSteps?()
    }

    @objc private func retryRequested() {
        onRetry?()
    }

    @objc private func closeRequested() {
        onClose?()
    }

    private func configureForLoadingOrError(messageVisible: Bool) {
        summarySectionView.isHidden = true
        causesSectionView.isHidden = true
        nextStepsSectionView.isHidden = true
        messageLabel.isHidden = messageVisible == false
    }

    private func configureForResult(_ result: AIAnalysisResult) {
        summarySectionView.setContent(result.summary)
        causesSectionView.setContent(result.possibleCauses)
        nextStepsSectionView.setContent(result.nextSteps)
        summarySectionView.isHidden = false
        causesSectionView.isHidden = false
        nextStepsSectionView.isHidden = false
        messageLabel.isHidden = true
    }

    private func presentPanel(
        selectionRect: CGRect,
        preferredSide: PreviewPlacementSide?
    ) {
        guard let screen = screenContaining(selectionRect) else {
            dismiss()
            return
        }

        let panelFrame = frame(
            for: selectionRect,
            on: screen,
            preferredSide: preferredSide
        )
        panel.setFrame(panelFrame, display: true)
        layoutContent(in: panelFrame.size)
        panel.orderFrontRegardless()
    }

    private func layoutContent(in size: CGSize) {
        containerView.frame = CGRect(origin: .zero, size: size)

        let padding: CGFloat = 14
        let buttonHeight: CGFloat = 28
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

        let buttonsTop = layoutActionButtons(
            in: size,
            padding: padding,
            spacing: spacing,
            buttonHeight: buttonHeight
        )
        let scrollTop = statusLabel.frame.minY - spacing
        let scrollBottom = buttonsTop + spacing
        scrollView.frame = CGRect(
            x: padding,
            y: scrollBottom,
            width: size.width - padding * 2,
            height: max(scrollTop - scrollBottom, 100)
        )

        layoutDocumentContent(in: scrollView.contentSize)
    }

    private func layoutActionButtons(
        in size: CGSize,
        padding: CGFloat,
        spacing: CGFloat,
        buttonHeight: CGFloat
    ) -> CGFloat {
        let buttonItems: [(button: NSButton, width: CGFloat)] = [
            (closeButton, 72),
            (retryButton, 72),
            (copyNextStepsButton, 96),
            (copyAllButton, 88)
        ]
        let availableWidth = max(size.width - padding * 2, 72)
        var rows: [[(button: NSButton, width: CGFloat)]] = [[]]
        var currentRowWidth: CGFloat = 0

        for item in buttonItems {
            let neededWidth = rows[rows.count - 1].isEmpty
                ? item.width
                : currentRowWidth + spacing + item.width

            if neededWidth > availableWidth, rows[rows.count - 1].isEmpty == false {
                rows.append([item])
                currentRowWidth = item.width
                continue
            }

            rows[rows.count - 1].append(item)
            currentRowWidth = neededWidth
        }

        var currentY = padding
        for row in rows {
            var trailingX = size.width - padding
            for item in row {
                trailingX -= item.width
                item.button.frame = CGRect(
                    x: trailingX,
                    y: currentY,
                    width: item.width,
                    height: buttonHeight
                )
                trailingX -= spacing
            }
            currentY += buttonHeight + spacing
        }

        return currentY - spacing
    }

    private func layoutDocumentContent(in size: CGSize) {
        let contentPadding: CGFloat = 8
        let sectionSpacing: CGFloat = 12
        let contentWidth = max(size.width - contentPadding * 2, 120)
        var currentY: CGFloat = contentPadding

        if summarySectionView.isHidden == false {
            let height = summarySectionView.preferredHeight(forWidth: contentWidth)
            summarySectionView.frame = CGRect(
                x: contentPadding,
                y: currentY,
                width: contentWidth,
                height: height
            )
            currentY += height + sectionSpacing
        } else {
            summarySectionView.frame = .zero
        }

        if causesSectionView.isHidden == false {
            let height = causesSectionView.preferredHeight(forWidth: contentWidth)
            causesSectionView.frame = CGRect(
                x: contentPadding,
                y: currentY,
                width: contentWidth,
                height: height
            )
            currentY += height + sectionSpacing
        } else {
            causesSectionView.frame = .zero
        }

        if nextStepsSectionView.isHidden == false {
            let height = nextStepsSectionView.preferredHeight(forWidth: contentWidth)
            nextStepsSectionView.frame = CGRect(
                x: contentPadding,
                y: currentY,
                width: contentWidth,
                height: height
            )
            currentY += height + sectionSpacing
        } else {
            nextStepsSectionView.frame = .zero
        }

        if messageLabel.isHidden == false {
            let messageSize = messageLabel.sizeThatFits(
                CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
            )
            messageLabel.frame = CGRect(
                x: contentPadding,
                y: currentY,
                width: contentWidth,
                height: messageSize.height
            )
            currentY += messageSize.height + contentPadding
        } else {
            messageLabel.frame = .zero
            currentY += contentPadding
        }

        documentContentView.frame = CGRect(
            x: 0,
            y: 0,
            width: size.width,
            height: max(currentY, size.height)
        )
    }

    private func frame(
        for selectionRect: CGRect,
        on screen: NSScreen,
        preferredSide: PreviewPlacementSide?
    ) -> CGRect {
        let visibleFrame = screen.visibleFrame
        let outerMargin: CGFloat = 24
        let gap: CGFloat = 20
        let minWidth: CGFloat = 320
        let maxWidth: CGFloat = 420
        let minHeight: CGFloat = 260
        let maxHeight: CGFloat = 480

        let leftAvailableWidth = selectionRect.minX - visibleFrame.minX - gap
        let rightAvailableWidth = visibleFrame.maxX - selectionRect.maxX - gap
        let leftEffectiveWidth = max(leftAvailableWidth - outerMargin, 0)
        let rightEffectiveWidth = max(rightAvailableWidth - outerMargin, 0)
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
            let preferredWidth = preferredPlaceOnLeft ? leftEffectiveWidth : rightEffectiveWidth
            let oppositeWidth = preferredPlaceOnLeft ? rightEffectiveWidth : leftEffectiveWidth
            placeOnLeft = preferredWidth >= minWidth || preferredWidth >= oppositeWidth
        } else {
            placeOnLeft = defaultPlaceOnLeft
        }

        let availableWidth = placeOnLeft ? leftEffectiveWidth : rightEffectiveWidth
        let availableHeight = max(visibleFrame.height - outerMargin * 2, 0)

        let panelWidth = min(max(availableWidth, minWidth), maxWidth)
        let panelHeight = min(max(availableHeight * 0.52, minHeight), maxHeight)

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

private final class FlippedContentView: NSView {
    override var isFlipped: Bool {
        true
    }
}

private final class SectionView: NSView {
    private let titleLabel: NSTextField
    private let contentLabel = NSTextField(wrappingLabelWithString: "")

    init(title: String) {
        titleLabel = NSTextField(labelWithString: title)
        super.init(frame: .zero)

        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.9)

        contentLabel.font = .systemFont(ofSize: 13)
        contentLabel.textColor = .white
        contentLabel.maximumNumberOfLines = 0
        contentLabel.lineBreakMode = .byWordWrapping

        addSubview(titleLabel)
        addSubview(contentLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func setContent(_ content: String) {
        contentLabel.stringValue = content
        needsLayout = true
    }

    func preferredHeight(forWidth width: CGFloat) -> CGFloat {
        let titleHeight = titleLabel.fittingSize.height
        let contentHeight = contentLabel.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        ).height
        return titleHeight + 6 + contentHeight
    }

    override func layout() {
        super.layout()

        let width = bounds.width
        let spacing: CGFloat = 6

        titleLabel.sizeToFit()
        titleLabel.frame = CGRect(
            x: 0,
            y: bounds.height - titleLabel.frame.height,
            width: width,
            height: titleLabel.frame.height
        )

        let contentSize = contentLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        contentLabel.frame = CGRect(
            x: 0,
            y: 0,
            width: width,
            height: contentSize.height
        )

        titleLabel.frame.origin.y = contentLabel.frame.maxY + spacing
    }

    override var intrinsicContentSize: NSSize {
        let width = bounds.width > 0 ? bounds.width : 300
        return NSSize(width: width, height: preferredHeight(forWidth: width))
    }
}
