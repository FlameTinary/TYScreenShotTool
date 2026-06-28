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

    // MARK: - Buttons

    private let cancelButton = ToolbarHoverButton()
    private let ocrButton = ToolbarHoverButton()
    private let translateButton = ToolbarHoverButton()
    private let aiButton = ToolbarHoverButton()
    private let saveButton = ToolbarHoverButton()
    private let copyButton = ToolbarHoverButton()

    // MARK: - Callbacks

    var onCancel: (() -> Void)?
    var onOCR: (() -> Void)?
    var onTranslate: (() -> Void)?
    var onAISelected: ((AIAnalysisMode) -> Void)?
    var onSave: (() -> Void)?
    var onCopy: (() -> Void)?

    /// 显示 tooltip 的回调，传递图片文字和按钮的屏幕坐标 frame
    var onTooltipShow: ((String, NSRect) -> Void)?
    /// 隐藏 tooltip 的回调
    var onTooltipHide: (() -> Void)?

    // MARK: - Button Size

    private static let toolbarButtonSize = CGSize(width: 30, height: 30)

    // MARK: - Layout

    private let stackView = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public API

    func configure(isOCREnabled: Bool, isTranslateEnabled: Bool, isAIEnabled: Bool) {
        ocrButton.isHidden = !isOCREnabled
        translateButton.isHidden = !isTranslateEnabled
        aiButton.isHidden = !isAIEnabled
        ocrButton.isEnabled = isOCREnabled
        translateButton.isEnabled = isTranslateEnabled
        aiButton.isEnabled = isAIEnabled
        applyButtonAppearance(ocrButton)
        applyButtonAppearance(translateButton)
        applyButtonAppearance(aiButton)
    }

    /// 当前可见按钮数量（用于计算工具栏宽度）
    var visibleButtonCount: Int {
        [cancelButton, ocrButton, translateButton, aiButton, saveButton, copyButton].filter { !$0.isHidden }.count
    }
}

// MARK: - Actions

private extension ScrollingCaptureControlPanelContentView {
    @objc func handleCancel() { onCancel?() }
    @objc func handleOCR() { onOCR?() }
    @objc func handleTranslate() { onTranslate?() }
    @objc func handleAI() {
        Task {
            await AIProPromptPresenter.show(from: self)
        }
    }
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
        configureButton(
            translateButton,
            symbolName: "translate",
            toolTip: AppText.captureTranslate,
            action: #selector(handleTranslate)
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

        let buttons = [cancelButton, ocrButton, translateButton, aiButton, saveButton, copyButton]
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
            self.handleHover(isHovered: isHovered, button: button)
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
            self.handleHover(isHovered: isHovered, button: button)
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

// MARK: - Hover Tooltip (delegated to ScrollingCapturePanelService)

private extension ScrollingCaptureControlPanelContentView {
    /// 将按钮的 hover 事件转换为回调，由 service 层用单独的 tooltip 浮窗显示
    func handleHover(isHovered: Bool, button: ToolbarHoverButton) {
        if isHovered {
            let text = button.hoverToolTip.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.isEmpty == false else { return }
            let buttonFrameInWindow = button.convert(button.bounds, to: nil)
            guard let windowFrame = window?.frame else { return }
            let buttonScreenFrame = NSRect(
                origin: NSPoint(
                    x: windowFrame.origin.x + buttonFrameInWindow.origin.x,
                    y: windowFrame.origin.y + buttonFrameInWindow.origin.y
                ),
                size: buttonFrameInWindow.size
            )
            onTooltipShow?(text, buttonScreenFrame)
        } else {
            onTooltipHide?()
        }
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
