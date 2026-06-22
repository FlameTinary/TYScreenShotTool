//
//  ScrollingCapturePanelService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/14.
//

import AppKit
import Foundation

@MainActor
final class ScrollingCapturePanelService {
    var onCopyRequested: (() -> Void)?
    var onSaveRequested: (() -> Void)?
    var onCancelRequested: (() -> Void)?
    var onOCRRequested: (() -> Void)? {
        didSet {
            panelView?.onOCRRequested = makePanelActionHandler(for: onOCRRequested)
        }
    }
    var onAIRequested: ((AIAnalysisMode) -> Void)? {
        didSet {
            panelView?.onAIRequested = makePanelActionHandler(for: onAIRequested)
        }
    }

    private var panel: ScrollingCapturePanel?
    private weak var panelView: ScrollingCapturePanelView?

    /// 显示长截图控制面板
    ///
    /// - Parameters:
    ///   - selectionRect: 当前选择的区域
    ///   - screen: 所在屏幕
    func presentCapturePanel(selectionRect: CGRect, on screen: NSScreen) {
        let panelView = ScrollingCapturePanelView(frame: CGRect(x: 0, y: 0, width: 440, height: 42))
        panelView.onCopyRequested = { [weak self] in
            self?.onCopyRequested?()
        }
        panelView.onSaveRequested = { [weak self] in
            self?.onSaveRequested?()
        }
        panelView.onCancelRequested = { [weak self] in
            self?.onCancelRequested?()
        }
        panelView.onOCRRequested = makePanelActionHandler(for: onOCRRequested)
        panelView.onAIRequested = makePanelActionHandler(for: onAIRequested)
        panelView.configureForLiveCapture()

        let panel = ScrollingCapturePanel(contentRect: panelView.bounds)
        panel.contentView = panelView
        panel.setFrame(originRect(for: panel.frame.size, selectionRect: selectionRect, on: screen), display: true)
        AppThemeCoordinator.shared.registerRefreshHandler(for: self) { [weak self] in
            guard let self, let panel = self.panel, let panelView = self.panelView else {
                return
            }

            AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
            panelView.applyAppearanceStyling()
        }
        AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
        panelView.applyAppearanceStyling()
        panel.orderFrontRegardless()

        self.panel = panel
        self.panelView = panelView
    }

    /// 关闭面板
    func dismissPanel() {
        AppThemeCoordinator.shared.unregisterRefreshHandler(for: self)
        panel?.orderOut(nil)
        panel = nil
        panelView = nil
    }

    private func originRect(for size: CGSize, selectionRect: CGRect, on screen: NSScreen) -> CGRect {
        let frame = screen.visibleFrame
        let x = min(
            max(selectionRect.midX - size.width / 2, frame.minX + 24),
            frame.maxX - size.width - 24
        )
        let y = max(frame.minY + 24, selectionRect.minY - size.height - 24)

        return CGRect(
            x: x,
            y: y,
            width: size.width,
            height: size.height
        )
    }

    private func makePanelActionHandler(for action: (() -> Void)?) -> (() -> Void)? {
        guard let action else {
            return nil
        }

        return {
            action()
        }
    }

    private func makePanelActionHandler(for action: ((AIAnalysisMode) -> Void)?) -> ((AIAnalysisMode) -> Void)? {
        guard let action else {
            return nil
        }

        return { mode in
            action(mode)
        }
    }
}

private final class ScrollingCapturePanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isFloatingPanel = true
        backgroundColor = .clear
        isOpaque = false
        // Keep the control panel above the long-capture guide overlay,
        // otherwise only the white selection frame remains visible.
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        hasShadow = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }
}

private final class ScrollingCapturePanelView: NSView {
    var onCopyRequested: (() -> Void)?
    var onSaveRequested: (() -> Void)?
    var onCancelRequested: (() -> Void)?
    var onOCRRequested: (() -> Void)? {
        didSet {
            ocrButton.isEnabled = onOCRRequested != nil
            applyButtonAppearance(ocrButton)
        }
    }
    var onAIRequested: ((AIAnalysisMode) -> Void)? {
        didSet {
            aiButton.isEnabled = onAIRequested != nil
            applyButtonAppearance(aiButton)
        }
    }

    private let materialView = NSVisualEffectView()
    private let copyButton = NSButton(title: "", target: nil, action: nil)
    private let saveButton = NSButton(title: "", target: nil, action: nil)
    private let cancelButton = NSButton(title: "", target: nil, action: nil)
    private let ocrButton = NSButton(title: "OCR", target: nil, action: nil)
    private let aiButton = NSButton(title: "AI", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        materialView.material = .popover
        materialView.blendingMode = .withinWindow
        materialView.state = .active
        materialView.wantsLayer = true
        materialView.layer?.cornerRadius = 12
        materialView.layer?.masksToBounds = true
        materialView.autoresizingMask = [.width, .height]
        addSubview(materialView)

        [cancelButton, ocrButton, aiButton, saveButton, copyButton].forEach { button in
            button.isBordered = false
            button.bezelStyle = .regularSquare
            button.focusRingType = .none
            button.font = .systemFont(ofSize: 13, weight: .medium)
            materialView.addSubview(button)
        }
        applyLocalizedStrings()
        applyAppearanceStyling()

        copyButton.target = self
        copyButton.action = #selector(copyAction)
        saveButton.target = self
        saveButton.action = #selector(saveAction)
        cancelButton.target = self
        cancelButton.action = #selector(cancelAction)
        ocrButton.target = self
        ocrButton.action = #selector(ocrAction)
        ocrButton.isEnabled = false
        aiButton.target = self
        aiButton.action = #selector(aiAction)
        aiButton.isEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        materialView.frame = bounds

        let paddingX: CGFloat = 12
        let buttonHeight: CGFloat = 30
        let buttonSpacing: CGFloat = 10
        let buttonWidth = (bounds.width - paddingX * 2 - buttonSpacing * 4) / 5
        let buttonY = (bounds.height - buttonHeight) / 2

        cancelButton.frame = CGRect(x: paddingX, y: buttonY, width: buttonWidth, height: buttonHeight)
        ocrButton.frame = CGRect(x: cancelButton.frame.maxX + buttonSpacing, y: buttonY, width: buttonWidth, height: buttonHeight)
        aiButton.frame = CGRect(x: ocrButton.frame.maxX + buttonSpacing, y: buttonY, width: buttonWidth, height: buttonHeight)
        saveButton.frame = CGRect(x: aiButton.frame.maxX + buttonSpacing, y: buttonY, width: buttonWidth, height: buttonHeight)
        copyButton.frame = CGRect(x: saveButton.frame.maxX + buttonSpacing, y: buttonY, width: buttonWidth, height: buttonHeight)
    }

    func configureForLiveCapture() {
        applyLocalizedStrings()
        applyAppearanceStyling()
        [cancelButton, ocrButton, aiButton, saveButton, copyButton].forEach(applyButtonAppearance)
        needsLayout = true
    }

    func applyAppearanceStyling() {
        materialView.material = .popover
        materialView.layer?.borderColor = NSColor.separatorColor.cgColor
        materialView.layer?.borderWidth = 1
        [cancelButton, ocrButton, aiButton, saveButton, copyButton].forEach(applyButtonAppearance)
    }

    private func applyButtonAppearance(_ button: NSButton) {
        button.wantsLayer = false
        button.layer?.backgroundColor = nil
        if button.isEnabled == false {
            button.alphaValue = 0.35
        } else {
            button.alphaValue = 1.0
        }
        button.needsDisplay = true
    }

    @objc
    private func copyAction() {
        onCopyRequested?()
    }

    @objc
    private func saveAction() {
        onSaveRequested?()
    }

    @objc
    private func cancelAction() {
        onCancelRequested?()
    }

    @objc
    private func ocrAction() {
        onOCRRequested?()
    }

    @objc
    private func aiAction() {
        presentAIMenu(relativeTo: aiButton)
    }

    private func presentAIMenu(relativeTo button: NSButton) {
        let menu = NSMenu()

        for mode in AIAnalysisMode.topLevelModes {
            let item = NSMenuItem(title: mode.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            menu.addItem(item)
        }

        let translationItem = NSMenuItem(
            title: AppText.aiTranslationMenu,
            action: nil,
            keyEquivalent: ""
        )
        let translationMenu = NSMenu()

        for language in AITranslationLanguage.allCases {
            let mode = AIAnalysisMode.translation(language)
            let item = NSMenuItem(title: mode.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            translationMenu.addItem(item)
        }

        menu.setSubmenu(translationMenu, for: translationItem)
        menu.addItem(translationItem)

        let menuOrigin = CGPoint(x: button.frame.minX, y: button.frame.maxY + 4)
        menu.popUp(positioning: nil, at: menuOrigin, in: self)
    }

    @objc
    private func handleAIMenuSelection(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? AIAnalysisMode else {
            return
        }

        onAIRequested?(mode)
    }

    private func applyLocalizedStrings() {
        copyButton.title = AppText.captureCopy
        saveButton.title = AppText.captureSave
        cancelButton.title = AppText.captureCancel
    }
}
