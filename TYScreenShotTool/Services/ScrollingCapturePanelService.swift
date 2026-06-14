//
//  ScrollingCapturePanelService.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/14.
//

import AppKit
import Foundation

final class ScrollingCapturePanelService {
    var onAppendRequested: (() -> Void)?
    var onFinishRequested: (() -> Void)?
    var onCopyRequested: (() -> Void)?
    var onSaveRequested: (() -> Void)?
    var onCancelRequested: (() -> Void)?

    private var panel: ScrollingCapturePanel?
    private weak var panelView: ScrollingCapturePanelView?

    func presentCapturePanel(on screen: NSScreen) {
        let panelView = ScrollingCapturePanelView(frame: CGRect(x: 0, y: 0, width: 360, height: 148))
        panelView.onAppendRequested = { [weak self] in
            self?.onAppendRequested?()
        }
        panelView.onFinishRequested = { [weak self] in
            self?.onFinishRequested?()
        }
        panelView.onCopyRequested = { [weak self] in
            self?.onCopyRequested?()
        }
        panelView.onSaveRequested = { [weak self] in
            self?.onSaveRequested?()
        }
        panelView.onCancelRequested = { [weak self] in
            self?.onCancelRequested?()
        }
        panelView.configureForCapture()

        let panel = ScrollingCapturePanel(contentRect: panelView.bounds)
        panel.contentView = panelView
        panel.setFrame(originRect(for: panel.frame.size, on: screen), display: true)
        panel.orderFrontRegardless()

        self.panel = panel
        self.panelView = panelView
    }

    func showResultPanel() {
        panelView?.configureForResult()
        panel?.orderFrontRegardless()
    }

    func dismissPanel() {
        panel?.orderOut(nil)
        panel = nil
        panelView = nil
    }

    private func originRect(for size: CGSize, on screen: NSScreen) -> CGRect {
        let frame = screen.visibleFrame
        return CGRect(
            x: frame.maxX - size.width - 24,
            y: frame.maxY - size.height - 24,
            width: size.width,
            height: size.height
        )
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
    var onAppendRequested: (() -> Void)?
    var onFinishRequested: (() -> Void)?
    var onCopyRequested: (() -> Void)?
    var onSaveRequested: (() -> Void)?
    var onCancelRequested: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(wrappingLabelWithString: "")
    private let primaryButton = NSButton(title: "", target: nil, action: nil)
    private let secondaryButton = NSButton(title: "", target: nil, action: nil)
    private let cancelButton = NSButton(title: "取消", target: nil, action: nil)
    private var mode: Mode = .capture

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.cornerRadius = 12

        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        descriptionLabel.font = .systemFont(ofSize: 12)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.maximumNumberOfLines = 3
        descriptionLabel.lineBreakMode = .byWordWrapping

        [primaryButton, secondaryButton, cancelButton].forEach {
            $0.bezelStyle = .rounded
            addSubview($0)
        }

        primaryButton.target = self
        primaryButton.action = #selector(primaryAction)
        secondaryButton.target = self
        secondaryButton.action = #selector(secondaryAction)
        cancelButton.target = self
        cancelButton.action = #selector(cancelAction)

        addSubview(titleLabel)
        addSubview(descriptionLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        let paddingX: CGFloat = 16
        let paddingTop: CGFloat = 16
        let buttonHeight: CGFloat = 30
        let buttonSpacing: CGFloat = 8
        let buttonWidth = (bounds.width - paddingX * 2 - buttonSpacing * 2) / 3

        titleLabel.sizeToFit()
        titleLabel.frame = CGRect(
            x: paddingX,
            y: bounds.height - paddingTop - titleLabel.frame.height,
            width: bounds.width - paddingX * 2,
            height: titleLabel.frame.height
        )

        let descriptionHeight: CGFloat = 42
        descriptionLabel.frame = CGRect(
            x: paddingX,
            y: titleLabel.frame.minY - 10 - descriptionHeight,
            width: bounds.width - paddingX * 2,
            height: descriptionHeight
        )

        let buttonY: CGFloat = 16
        primaryButton.frame = CGRect(x: paddingX, y: buttonY, width: buttonWidth, height: buttonHeight)
        secondaryButton.frame = CGRect(x: primaryButton.frame.maxX + buttonSpacing, y: buttonY, width: buttonWidth, height: buttonHeight)
        cancelButton.frame = CGRect(x: secondaryButton.frame.maxX + buttonSpacing, y: buttonY, width: buttonWidth, height: buttonHeight)
    }

    func configureForCapture() {
        mode = .capture
        titleLabel.stringValue = "长截图"
        descriptionLabel.stringValue = "请滚动目标内容，每滚动到下一屏后点击“追加当前屏”，完成后点击“完成长截图”。"
        primaryButton.title = "追加当前屏"
        secondaryButton.title = "完成长截图"
        needsLayout = true
    }

    func configureForResult() {
        mode = .result
        titleLabel.stringValue = "长截图已生成"
        descriptionLabel.stringValue = "现在可以复制长图或保存到当前默认目录。"
        primaryButton.title = "复制长图"
        secondaryButton.title = "保存长图"
        needsLayout = true
    }

    @objc
    private func primaryAction() {
        switch mode {
        case .capture:
            onAppendRequested?()
        case .result:
            onCopyRequested?()
        }
    }

    @objc
    private func secondaryAction() {
        switch mode {
        case .capture:
            onFinishRequested?()
        case .result:
            onSaveRequested?()
        }
    }

    @objc
    private func cancelAction() {
        onCancelRequested?()
    }

    private enum Mode {
        case capture
        case result
    }
}
