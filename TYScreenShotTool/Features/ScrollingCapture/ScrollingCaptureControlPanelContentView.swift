//
//  ScrollingCaptureControlPanelContentView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/22.
//

import AppKit
import SnapKit

@MainActor
final class ScrollingCaptureControlPanelContentView: NSView {
    // MARK: - Constants

    private let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
    private let buttonTintColor = NSColor.white
    private let disabledTintColor = NSColor.white.withAlphaComponent(0.35)
    private static let tooltipOffset: CGFloat = 8

    // MARK: - Buttons

    private let cancelButton = ToolbarHoverButton()
    private let ocrButton = ToolbarHoverButton()
    private let aiButton = ToolbarHoverButton()
    private let saveButton = ToolbarHoverButton()
    private let copyButton = ToolbarHoverButton()

    // MARK: - Tooltip

    private let tooltipView = NSVisualEffectView()
    private let tooltipLabel = NSTextField(labelWithString: "")

    // MARK: - Callbacks

    var onCancel: (() -> Void)?
    var onOCR: (() -> Void)?
    var onAISelected: ((AIAnalysisMode) -> Void)?
    var onSave: (() -> Void)?
    var onCopy: (() -> Void)?

    // MARK: - Button Size

    private static let toolbarButtonSize = CGSize(width: 30, height: 30)

    // MARK: - Layout

    private let stackView = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
        configureTooltip()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public API

    func configure(isOCREnabled: Bool, isAIEnabled: Bool) {
        ocrButton.isHidden = !isOCREnabled
        aiButton.isHidden = !isAIEnabled
        ocrButton.isEnabled = isOCREnabled
        aiButton.isEnabled = isAIEnabled
        applyButtonAppearance(ocrButton)
        applyButtonAppearance(aiButton)
    }

    /// 当前可见按钮数量（用于计算工具栏宽度）
    var visibleButtonCount: Int {
        [cancelButton, ocrButton, aiButton, saveButton, copyButton].filter { !$0.isHidden }.count
    }
}

// MARK: - Actions

private extension ScrollingCaptureControlPanelContentView {
    @objc func handleCancel() { onCancel?() }
    @objc func handleOCR() { onOCR?() }
    @objc func handleAI() { presentAIMenu() }
    @objc func handleSave() { onSave?() }
    @objc func handleCopy() { onCopy?() }
}

// MARK: - Layout & Button Configuration

private extension ScrollingCaptureControlPanelContentView {
    func buildLayout() {
        stackView.orientation = .horizontal
        stackView.spacing = 10
        stackView.alignment = .centerY

        // Configure all buttons with icons matching the normal capture toolbar
        configureButton(
            cancelButton,
            symbolName: "xmark",
            toolTip: AppText.captureCancel,
            action: #selector(handleCancel)
        )
        configureSVGButton(
            ocrButton,
            resourceName: "icon-ocr",
            toolTip: "OCR",
            action: #selector(handleOCR)
        )
        configureSVGButton(
            aiButton,
            resourceName: "icon-ai",
            toolTip: "AI",
            action: #selector(handleAI)
        )
        configureButton(
            saveButton,
            symbolName: "square.and.arrow.down",
            toolTip: AppText.captureSave,
            action: #selector(handleSave)
        )
        configureButton(
            copyButton,
            symbolName: "doc.on.doc",
            toolTip: AppText.captureCopy,
            action: #selector(handleCopy)
        )

        let buttons = [cancelButton, ocrButton, aiButton, saveButton, copyButton]
        stackView.setViews(buttons, in: .leading)
        addSubview(stackView)

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12))
        }
    }

    func configureButton(
        _ button: ToolbarHoverButton,
        symbolName: String,
        toolTip: String,
        action: Selector
    ) {
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(symbolConfiguration) ?? NSImage()

        button.image = image
        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.focusRingType = .none
        button.hoverToolTip = toolTip
        button.onHoverChanged = { [weak self, weak button] isHovered in
            guard let self, let button else { return }
            self.handleButtonHover(isHovered: isHovered, button: button)
        }
        button.target = self
        button.action = action
        button.snp.makeConstraints { make in
            make.size.equalTo(Self.toolbarButtonSize)
        }
        applyButtonAppearance(button)
    }

    func configureSVGButton(
        _ button: ToolbarHoverButton,
        resourceName: String,
        toolTip: String,
        action: Selector
    ) {
        let imageName = resourceName
        let image = (NSImage(named: imageName) ?? NSImage()) as NSImage
        image.isTemplate = true

        button.image = image
        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.focusRingType = .none
        button.hoverToolTip = toolTip
        button.onHoverChanged = { [weak self, weak button] isHovered in
            guard let self, let button else { return }
            self.handleButtonHover(isHovered: isHovered, button: button)
        }
        button.target = self
        button.action = action
        button.snp.makeConstraints { make in
            make.size.equalTo(Self.toolbarButtonSize)
        }
        applyButtonAppearance(button)
    }

    func applyButtonAppearance(_ button: ToolbarHoverButton) {
        button.wantsLayer = false
        button.layer?.backgroundColor = nil
        button.contentTintColor = button.isEnabled ? buttonTintColor : disabledTintColor
        button.needsDisplay = true
    }
}

// MARK: - Tooltip

private extension ScrollingCaptureControlPanelContentView {
    func configureTooltip() {
        tooltipView.material = .popover
        tooltipView.blendingMode = .withinWindow
        tooltipView.state = .active
        tooltipView.wantsLayer = true
        tooltipView.layer?.cornerRadius = 8
        tooltipView.layer?.masksToBounds = true
        tooltipView.isHidden = true

        tooltipLabel.font = .systemFont(ofSize: 12, weight: .medium)
        tooltipLabel.textColor = .labelColor
        tooltipView.addSubview(tooltipLabel)

        // Add tooltip after the stack view so it renders on top
        addSubview(tooltipView)
    }

    func handleButtonHover(isHovered: Bool, button: ToolbarHoverButton) {
        if isHovered {
            showTooltip(for: button)
        } else {
            hideTooltip()
        }
    }

    func showTooltip(for button: ToolbarHoverButton) {
        let tooltip = button.hoverToolTip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard tooltip.isEmpty == false else {
            hideTooltip()
            return
        }

        tooltipLabel.stringValue = tooltip
        tooltipLabel.sizeToFit()

        let paddingX: CGFloat = 10
        let paddingY: CGFloat = 6
        let width = tooltipLabel.frame.width + paddingX * 2
        let height = tooltipLabel.frame.height + paddingY * 2
        tooltipView.frame.size = CGSize(width: width, height: height)
        tooltipLabel.frame.origin = CGPoint(
            x: paddingX,
            y: (height - tooltipLabel.frame.height) / 2
        )

        positionTooltip(relativeTo: button)
        tooltipView.isHidden = false
    }

    func hideTooltip() {
        tooltipView.isHidden = true
    }

    func positionTooltip(relativeTo button: ToolbarHoverButton) {
        let buttonFrame = convert(button.bounds, from: button)
        let preferredX = buttonFrame.midX - tooltipView.frame.width / 2
        let clampedX = min(
            max(preferredX, 16),
            bounds.width - tooltipView.frame.width - 16
        )

        // Show above the button by default
        var tooltipY = buttonFrame.minY - tooltipView.frame.height - Self.tooltipOffset
        if tooltipY < 0 {
            // Not enough space above, flip below
            tooltipY = buttonFrame.maxY + Self.tooltipOffset
        }

        tooltipView.frame.origin = CGPoint(x: clampedX, y: tooltipY)
    }
}

// MARK: - AI Menu

private extension ScrollingCaptureControlPanelContentView {
    func presentAIMenu() {
        let menu = NSMenu()

        for mode in AIAnalysisMode.topLevelModes {
            let item = NSMenuItem(title: mode.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            menu.addItem(item)
        }

        let translationMenu = NSMenu()
        for language in AITranslationLanguage.allCases {
            let item = NSMenuItem(title: language.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = AIAnalysisMode.translation(language)
            translationMenu.addItem(item)
        }

        let translationItem = NSMenuItem(title: AppText.aiTranslationMenu, action: nil, keyEquivalent: "")
        translationItem.submenu = translationMenu
        menu.addItem(.separator())
        menu.addItem(translationItem)

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: aiButton)
        } else {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: aiButton.bounds.height), in: aiButton)
        }
    }

    @objc func handleAIMenuSelection(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? AIAnalysisMode else { return }
        onAISelected?(mode)
    }
}
