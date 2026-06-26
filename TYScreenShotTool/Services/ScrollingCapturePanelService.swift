//
//  ScrollingCapturePanelService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/14.
//

import AppKit
import Foundation
import SnapKit

@MainActor
final class ScrollingCapturePanelService {
    var onCopyRequested: (() -> Void)?
    var onSaveRequested: (() -> Void)?
    var onCancelRequested: (() -> Void)?
    var onOCRRequested: (() -> Void)?
    var onAIRequested: ((AIAnalysisMode) -> Void)?

    private var panel: ScrollingCapturePanel?
    private let containerView = NSVisualEffectView()
    private let contentView = ScrollingCaptureControlPanelContentView()

    // MARK: - Tooltip

    private var tooltipPanel: NSPanel?
    private let tooltipView = NSVisualEffectView()
    private let tooltipLabel = NSTextField(labelWithString: "")

    /// 显示长截图控制面板
    ///
    /// - Parameters:
    ///   - selectionRect: 当前选择的区域
    ///   - screen: 所在屏幕
    func presentCapturePanel(selectionRect: CGRect, on screen: NSScreen) {
        let panelInstance: ScrollingCapturePanel
        if let existingPanel = self.panel {
            panelInstance = existingPanel
        } else {
            let createdPanel = ScrollingCapturePanel(contentRect: CGRect(x: 0, y: 0, width: 480, height: 42))
            self.panel = createdPanel
            panelInstance = createdPanel
        }

        if panelInstance.contentView !== containerView {
            panelInstance.contentView = containerView
            containerView.addSubview(contentView)
            contentView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        containerView.material = .popover
        containerView.blendingMode = .withinWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.masksToBounds = true

        contentView.onCancel = { [weak self] in self?.onCancelRequested?() }
        contentView.onOCR = { [weak self] in self?.onOCRRequested?() }
        contentView.onAISelected = { [weak self] mode in self?.onAIRequested?(mode) }
        contentView.onSave = { [weak self] in self?.onSaveRequested?() }
        contentView.onCopy = { [weak self] in self?.onCopyRequested?() }
        contentView.onTooltipShow = { [weak self] text, buttonFrame in
            self?.showTooltip(text: text, buttonScreenFrame: buttonFrame)
        }
        contentView.onTooltipHide = { [weak self] in
            self?.hideTooltip()
        }
        contentView.configure(
            isOCREnabled: onOCRRequested != nil,
            isAIEnabled: onAIRequested != nil
        )

        setupTooltipPanel()

        let panelSize = measuredPanelFrameSize(for: panelInstance, selectionRect: selectionRect, on: screen)
        panelInstance.setFrame(originRect(for: panelSize, selectionRect: selectionRect, on: screen), display: true)

        AppThemeCoordinator.shared.registerRefreshHandler(for: self) { [weak self] in
            guard let self, let panel = self.panel else {
                return
            }

            AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
            self.applyAppearanceStyling()
        }

        AppThemeCoordinator.shared.applyCurrentAppearance(to: panelInstance)
        applyAppearanceStyling()
        panelInstance.orderFrontRegardless()
    }

    /// 关闭面板
    func dismissPanel() {
        AppThemeCoordinator.shared.unregisterRefreshHandler(for: self)
        hideTooltip()
        tooltipPanel = nil
        panel?.orderOut(nil)
        panel = nil
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

    private func measuredPanelFrameSize(for panel: NSPanel, selectionRect: CGRect, on screen: NSScreen) -> CGSize {
        let frame = screen.visibleFrame
        let horizontalPadding: CGFloat = 48
        let availableWidth = min(
            selectionRect.midX - frame.minX - horizontalPadding,
            frame.maxX - selectionRect.midX - horizontalPadding
        ) * 2

        let buttonSize: CGFloat = 30
        let spacing: CGFloat = 10
        let sidePadding: CGFloat = 12 * 2

        let visibleCount = contentView.visibleButtonCount
        let contentWidth = CGFloat(visibleCount) * buttonSize
            + CGFloat(max(visibleCount - 1, 0)) * spacing
            + sidePadding
        let contentHeight = buttonSize + 6 * 2

        let clampedWidth = min(contentWidth, max(availableWidth, 140))
        let contentSize = CGSize(width: clampedWidth, height: contentHeight)
        return panel.frameRect(forContentRect: CGRect(origin: .zero, size: contentSize)).size
    }

    private func applyAppearanceStyling() {
        containerView.material = .popover
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
        containerView.layer?.borderWidth = 1
    }

    // MARK: - Tooltip

    private func setupTooltipPanel() {
        guard tooltipPanel == nil else { return }

        let tipPanel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        tipPanel.isFloatingPanel = true
        tipPanel.isOpaque = false
        tipPanel.backgroundColor = .clear
        tipPanel.hasShadow = false
        tipPanel.ignoresMouseEvents = true
        tipPanel.level = panel?.level ?? NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        tipPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        tooltipView.material = .popover
        tooltipView.blendingMode = .withinWindow
        tooltipView.state = .active
        tooltipView.wantsLayer = true
        tooltipView.layer?.cornerRadius = 8
        tooltipView.layer?.masksToBounds = true

        tooltipLabel.font = .systemFont(ofSize: 12, weight: .medium)
        tooltipLabel.textColor = .labelColor

        tooltipView.addSubview(tooltipLabel)
        tipPanel.contentView = tooltipView

        tooltipPanel = tipPanel
    }

    private func showTooltip(text: String, buttonScreenFrame: NSRect) {
        guard let tipPanel = tooltipPanel else { return }

        tooltipLabel.stringValue = text
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

        // 与普通截图工具栏一致：默认显示在按钮下方，空间不足时翻转至上方
        let tooltipOffset: CGFloat = 10
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let preferredX = min(
            max(buttonScreenFrame.midX - width / 2, screenFrame.minX + 8),
            screenFrame.maxX - width - 8
        )
        let tooltipY: CGFloat
        if buttonScreenFrame.minY - height - tooltipOffset >= screenFrame.minY {
            tooltipY = buttonScreenFrame.minY - height - tooltipOffset // 下方
        } else {
            tooltipY = buttonScreenFrame.maxY + tooltipOffset         // 上方
        }

        tipPanel.setFrame(CGRect(x: preferredX, y: tooltipY, width: width, height: height), display: false)
        tipPanel.orderFrontRegardless()
    }

    private func hideTooltip() {
        tooltipPanel?.orderOut(nil)
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
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        backgroundColor = .clear
        isOpaque = false
        // Keep the control panel above the long-capture guide overlay,
        // otherwise only the white selection frame remains visible.
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        hasShadow = true
    }
}
