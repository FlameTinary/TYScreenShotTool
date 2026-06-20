//
//  ScrollingCapturePanelService.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/14.
//

import AppKit
import Foundation

final class ScrollingCapturePanelService {
    var onCopyRequested: (() -> Void)?
    var onSaveRequested: (() -> Void)?
    var onCancelRequested: (() -> Void)?
    var onOCRRequested: (() -> Void)? {
        didSet {
            panelView?.onOCRRequested = makePanelActionHandler(for: onOCRRequested)
        }
    }
    var onAIRequested: (() -> Void)? {
        didSet {
            panelView?.onAIRequested = makePanelActionHandler(for: onAIRequested)
        }
    }

    private var panel: ScrollingCapturePanel?
    private weak var panelView: ScrollingCapturePanelView?

    func presentCapturePanel(selectionRect: CGRect, on screen: NSScreen) {
        let panelView = ScrollingCapturePanelView(frame: CGRect(x: 0, y: 0, width: 440, height: 56))
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
        panel.orderFrontRegardless()

        self.panel = panel
        self.panelView = panelView
    }

    func dismissPanel() {
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
        }
    }
    var onAIRequested: (() -> Void)? {
        didSet {
            aiButton.isEnabled = onAIRequested != nil
        }
    }
    private let copyButton = NSButton(title: "复制", target: nil, action: nil)
    private let saveButton = NSButton(title: "保存", target: nil, action: nil)
    private let cancelButton = NSButton(title: "取消", target: nil, action: nil)
    private let ocrButton = NSButton(title: "OCR", target: nil, action: nil)
    private let aiButton = NSButton(title: "AI", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 12
        [cancelButton, ocrButton, aiButton, saveButton, copyButton].forEach {
            $0.bezelStyle = .rounded
            addSubview($0)
        }

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
        needsLayout = true
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
        onAIRequested?()
    }
}
