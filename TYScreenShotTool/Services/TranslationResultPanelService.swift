//
//  TranslationResultPanelService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/27.
//

import AppKit
import SnapKit

/// 翻译结果浮动面板服务
///
/// 展示 OCR 识别原文和本地翻译结果的浮动面板。
@MainActor
final class TranslationResultPanelService {
    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let containerView = NSVisualEffectView()
    private let contentView = TranslationResultContentView()

    init() {
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        containerView.material = .popover
        containerView.blendingMode = .withinWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 14
        containerView.layer?.borderWidth = 1

        panel.contentView = containerView
        containerView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        AppThemeCoordinator.shared.registerRefreshHandler(for: self) { [weak self] in
            self?.applyAppearanceStyling()
        }
        applyAppearanceStyling()
    }

    deinit {
        let ownerID = ObjectIdentifier(self)
        Task { @MainActor in
            AppThemeCoordinator.shared.unregisterRefreshHandler(for: ownerID)
        }
    }

    /// 显示翻译结果
    ///
    /// - Parameters:
    ///   - sourceText: 原文
    ///   - translatedText: 译文
    ///   - selectionRect: 选择区域
    ///   - onCopySource: 复制原文回调
    ///   - onCopyTarget: 复制译文回调
    ///   - onClose: 关闭回调
    func present(
        sourceText: String,
        translatedText: String,
        selectionRect: CGRect,
        onCopySource: @escaping () -> Void,
        onCopyTarget: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        guard let screen = screenContaining(selectionRect) else {
            dismiss()
            return
        }

        contentView.configure(
            sourceText: sourceText,
            translatedText: translatedText,
            onCopySource: onCopySource,
            onCopyTarget: onCopyTarget,
            onClose: onClose
        )

        let panelFrame = frame(for: selectionRect, on: screen)
        AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
        panel.setFrame(panelFrame, display: true)
        applyAppearanceStyling()
        panel.orderFrontRegardless()
    }

    /// 显示空状态（OCR 结果为空）
    ///
    /// - Parameters:
    ///   - message: 空状态提示信息
    ///   - selectionRect: 选择区域
    ///   - onClose: 关闭回调
    func presentEmpty(
        message: String,
        selectionRect: CGRect,
        onClose: @escaping () -> Void
    ) {
        guard let screen = screenContaining(selectionRect) else {
            dismiss()
            return
        }

        contentView.configureEmpty(
            message: message,
            onClose: onClose
        )

        let panelFrame = frame(for: selectionRect, on: screen)
        AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
        panel.setFrame(panelFrame, display: true)
        applyAppearanceStyling()
        panel.orderFrontRegardless()
    }

    /// 显示错误状态
    ///
    /// - Parameters:
    ///   - message: 错误提示信息
    ///   - selectionRect: 选择区域
    ///   - onClose: 关闭回调
    func presentError(
        message: String,
        selectionRect: CGRect,
        onClose: @escaping () -> Void
    ) {
        guard let screen = screenContaining(selectionRect) else {
            dismiss()
            return
        }

        contentView.configureEmpty(
            message: message,
            onClose: onClose
        )

        let panelFrame = frame(for: selectionRect, on: screen)
        AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
        panel.setFrame(panelFrame, display: true)
        applyAppearanceStyling()
        panel.orderFrontRegardless()
    }

    func dismiss() {
        panel.orderOut(nil)
    }

    // MARK: - Private

    private func applyAppearanceStyling() {
        containerView.material = .popover
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
    }

    private func frame(
        for selectionRect: CGRect,
        on screen: NSScreen
    ) -> CGRect {
        let visibleFrame = screen.visibleFrame
        let outerMargin: CGFloat = 24
        let gap: CGFloat = 20
        let minWidth: CGFloat = 280
        let maxWidth: CGFloat = 400
        let minHeight: CGFloat = 280
        let maxHeight: CGFloat = 460

        let leftAvailableWidth = selectionRect.minX - visibleFrame.minX - gap
        let rightAvailableWidth = visibleFrame.maxX - selectionRect.maxX - gap
        let leftEffectiveWidth = max(leftAvailableWidth - outerMargin, 0)
        let rightEffectiveWidth = max(rightAvailableWidth - outerMargin, 0)
        let placeOnLeft = leftAvailableWidth >= rightAvailableWidth

        let availableWidth = placeOnLeft ? leftEffectiveWidth : rightEffectiveWidth
        let availableHeight = max(visibleFrame.height - outerMargin * 2, 0)

        let panelWidth = min(max(max(availableWidth, minWidth), minWidth), maxWidth)
        let panelHeight = min(max(max(availableHeight * 0.5, minHeight), minHeight), maxHeight)

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

// MARK: - Translation Result Content View

/// 翻译结果内容视图
private final class TranslationResultContentView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let sourceLabel = NSTextField(labelWithString: "")
    private let sourceScrollView = NSScrollView()
    private let sourceTextView = NSTextView()
    private let targetLabel = NSTextField(labelWithString: "")
    private let targetScrollView = NSScrollView()
    private let targetTextView = NSTextView()
    private let copySourceButton = NSButton()
    private let copyTargetButton = NSButton()
    private let closeButton = NSButton()

    private var onCopySource: (() -> Void)?
    private var onCopyTarget: (() -> Void)?
    private var onClose: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        sourceText: String,
        translatedText: String,
        onCopySource: @escaping () -> Void,
        onCopyTarget: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onCopySource = onCopySource
        self.onCopyTarget = onCopyTarget
        self.onClose = onClose

        titleLabel.stringValue = AppLocalization.text("translate.window.title")
        sourceLabel.stringValue = AppLocalization.text("translate.source_text")
        targetLabel.stringValue = AppLocalization.text("translate.target_text")
        copySourceButton.title = AppLocalization.text("translate.copy_source")
        copyTargetButton.title = AppLocalization.text("translate.copy_target")
        closeButton.title = AppLocalization.text("translate.close")

        sourceTextView.string = sourceText
        targetTextView.string = translatedText

        copySourceButton.isHidden = sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        copyTargetButton.isHidden = translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func configureEmpty(
        message: String,
        onClose: @escaping () -> Void
    ) {
        self.onCopySource = nil
        self.onCopyTarget = nil
        self.onClose = onClose

        titleLabel.stringValue = AppLocalization.text("translate.window.title")
        sourceLabel.stringValue = ""
        targetLabel.stringValue = ""
        copySourceButton.isHidden = true
        copyTargetButton.isHidden = true
        closeButton.title = AppLocalization.text("translate.close")

        // 在原文区域显示提示信息
        sourceTextView.string = message
        targetTextView.string = ""
    }

    // MARK: - Layout

    private func buildLayout() {
        let padding: CGFloat = 16
        let spacing: CGFloat = 10
        let labelHeight: CGFloat = 18
        let buttonHeight: CGFloat = 28

        // Title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        addSubview(titleLabel)

        // Source label
        sourceLabel.font = .systemFont(ofSize: 11, weight: .medium)
        sourceLabel.textColor = .secondaryLabelColor
        sourceLabel.isEditable = false
        sourceLabel.isSelectable = false
        sourceLabel.isBezeled = false
        sourceLabel.drawsBackground = false
        addSubview(sourceLabel)

        // Source text view
        sourceTextView.isEditable = false
        sourceTextView.isSelectable = true
        sourceTextView.font = .systemFont(ofSize: 12)
        sourceTextView.textColor = .labelColor
        sourceTextView.drawsBackground = false
        sourceTextView.backgroundColor = .clear
        sourceTextView.textContainerInset = NSSize(width: 8, height: 6)
        sourceScrollView.documentView = sourceTextView
        sourceScrollView.hasVerticalScroller = true
        sourceScrollView.hasHorizontalScroller = false
        sourceScrollView.autohidesScrollers = true
        sourceScrollView.borderType = .bezelBorder
        sourceScrollView.wantsLayer = true
        sourceScrollView.layer?.cornerRadius = 6
        sourceScrollView.layer?.masksToBounds = true
        addSubview(sourceScrollView)

        // Target label
        targetLabel.font = .systemFont(ofSize: 11, weight: .medium)
        targetLabel.textColor = .secondaryLabelColor
        targetLabel.isEditable = false
        targetLabel.isSelectable = false
        targetLabel.isBezeled = false
        targetLabel.drawsBackground = false
        addSubview(targetLabel)

        // Target text view
        targetTextView.isEditable = false
        targetTextView.isSelectable = true
        targetTextView.font = .systemFont(ofSize: 12)
        targetTextView.textColor = .labelColor
        targetTextView.drawsBackground = false
        targetTextView.backgroundColor = .clear
        targetTextView.textContainerInset = NSSize(width: 8, height: 6)
        targetScrollView.documentView = targetTextView
        targetScrollView.hasVerticalScroller = true
        targetScrollView.hasHorizontalScroller = false
        targetScrollView.autohidesScrollers = true
        targetScrollView.borderType = .bezelBorder
        targetScrollView.wantsLayer = true
        targetScrollView.layer?.cornerRadius = 6
        targetScrollView.layer?.masksToBounds = true
        addSubview(targetScrollView)

        // Buttons
        copySourceButton.bezelStyle = .rounded
        copySourceButton.font = .systemFont(ofSize: 12)
        copySourceButton.target = self
        copySourceButton.action = #selector(handleCopySource)
        addSubview(copySourceButton)

        copyTargetButton.bezelStyle = .rounded
        copyTargetButton.font = .systemFont(ofSize: 12)
        copyTargetButton.target = self
        copyTargetButton.action = #selector(handleCopyTarget)
        addSubview(copyTargetButton)

        closeButton.bezelStyle = .rounded
        closeButton.font = .systemFont(ofSize: 12)
        closeButton.target = self
        closeButton.action = #selector(handleClose)
        addSubview(closeButton)

        // Layout constraints
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(padding)
            make.leading.equalToSuperview().offset(padding)
            make.trailing.equalToSuperview().offset(-padding)
        }

        sourceLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(spacing)
            make.leading.equalToSuperview().offset(padding)
            make.trailing.equalToSuperview().offset(-padding)
        }

        sourceScrollView.snp.makeConstraints { make in
            make.top.equalTo(sourceLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(padding)
            make.trailing.equalToSuperview().offset(-padding)
            make.height.equalTo(100).priority(.medium)
        }

        targetLabel.snp.makeConstraints { make in
            make.top.equalTo(sourceScrollView.snp.bottom).offset(spacing)
            make.leading.equalToSuperview().offset(padding)
            make.trailing.equalToSuperview().offset(-padding)
        }

        targetScrollView.snp.makeConstraints { make in
            make.top.equalTo(targetLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(padding)
            make.trailing.equalToSuperview().offset(-padding)
            make.height.equalTo(100).priority(.medium)
        }

        copySourceButton.snp.makeConstraints { make in
            make.top.equalTo(targetScrollView.snp.bottom).offset(spacing)
            make.leading.equalToSuperview().offset(padding)
            make.height.equalTo(buttonHeight)
        }

        copyTargetButton.snp.makeConstraints { make in
            make.centerY.equalTo(copySourceButton)
            make.leading.equalTo(copySourceButton.snp.trailing).offset(8)
            make.height.equalTo(buttonHeight)
        }

        closeButton.snp.makeConstraints { make in
            make.centerY.equalTo(copySourceButton)
            make.trailing.equalToSuperview().offset(-padding)
            make.height.equalTo(buttonHeight)
        }

        // Bottom constraint
        copySourceButton.snp.makeConstraints { make in
            make.bottom.lessThanOrEqualToSuperview().offset(-padding)
        }
    }

    // MARK: - Actions

    @objc private func handleCopySource() {
        onCopySource?()
    }

    @objc private func handleCopyTarget() {
        onCopyTarget?()
    }

    @objc private func handleClose() {
        onClose?()
    }
}
