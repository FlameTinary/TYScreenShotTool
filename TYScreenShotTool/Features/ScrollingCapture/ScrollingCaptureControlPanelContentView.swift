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
    private let rootStackView = NSStackView()
    private let firstRowStackView = NSStackView()
    private let secondRowStackView = NSStackView()
    private let cancelButton = NSButton(title: "", target: nil, action: nil)
    private let ocrButton = NSButton(title: "", target: nil, action: nil)
    private let aiButton = NSButton(title: "", target: nil, action: nil)
    private let saveButton = NSButton(title: "", target: nil, action: nil)
    private let copyButton = NSButton(title: "", target: nil, action: nil)

    var onCancel: (() -> Void)?
    var onOCR: (() -> Void)?
    var onAISelected: ((AIAnalysisMode) -> Void)?
    var onSave: (() -> Void)?
    var onCopy: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        cancelButton.target = self
        cancelButton.action = #selector(handleCancel)
        ocrButton.target = self
        ocrButton.action = #selector(handleOCR)
        aiButton.target = self
        aiButton.action = #selector(handleAI)
        saveButton.target = self
        saveButton.action = #selector(handleSave)
        copyButton.target = self
        copyButton.action = #selector(handleCopy)
    }

    func configure(isOCREnabled: Bool, isAIEnabled: Bool) {
        cancelButton.title = AppText.captureCancel
        ocrButton.title = AppText.captureOCR
        aiButton.title = AppText.captureAI
        saveButton.title = AppText.captureSave
        copyButton.title = AppText.captureCopy
        ocrButton.isEnabled = isOCREnabled
        aiButton.isEnabled = isAIEnabled
        arrangeButtons()
    }

    /// 在 buildLayout 中调用一次，数据变化时再次调用。
    /// 为宽模式排列按钮。窄模式回退（第二行）仅在显式调用 configure() 时触发 ——
    /// 从不在布局期间触发，因为 NSPanel 不可调整大小，所以宽度在运行时不会改变。
    private func arrangeButtons() {
        let compact = bounds.width < 430
        secondRowStackView.isHidden = compact == false

        if compact {
            firstRowStackView.setViews([cancelButton, ocrButton, aiButton], in: .leading)
            secondRowStackView.setViews([saveButton, copyButton], in: .leading)
        } else {
            firstRowStackView.setViews([cancelButton, ocrButton, aiButton, saveButton, copyButton], in: .leading)
            secondRowStackView.setViews([], in: .leading)
        }
    }

    @objc private func handleCancel() { onCancel?() }
    @objc private func handleOCR() { onOCR?() }
    @objc private func handleAI() { presentAIMenu() }
    @objc private func handleSave() { onSave?() }
    @objc private func handleCopy() { onCopy?() }
}

// MARK: - Layout

private extension ScrollingCaptureControlPanelContentView {
    func buildLayout() {
        firstRowStackView.orientation = .horizontal
        firstRowStackView.spacing = 10
        firstRowStackView.alignment = .centerY

        secondRowStackView.orientation = .horizontal
        secondRowStackView.spacing = 10
        secondRowStackView.alignment = .centerY

        rootStackView.orientation = .vertical
        rootStackView.spacing = 8
        rootStackView.alignment = .leading

        rootStackView.addArrangedSubview(firstRowStackView)
        rootStackView.addArrangedSubview(secondRowStackView)

        addSubview(rootStackView)
        rootStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12))
        }

        arrangeButtons()
    }

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
