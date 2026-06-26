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
        containerView.layer?.masksToBounds = false

        contentView.onCancel = { [weak self] in self?.onCancelRequested?() }
        contentView.onOCR = { [weak self] in self?.onOCRRequested?() }
        contentView.onAISelected = { [weak self] mode in self?.onAIRequested?(mode) }
        contentView.onSave = { [weak self] in self?.onSaveRequested?() }
        contentView.onCopy = { [weak self] in self?.onCopyRequested?() }
        contentView.configure(
            isOCREnabled: onOCRRequested != nil,
            isAIEnabled: onAIRequested != nil
        )

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
        let compact = availableWidth < 430
        let contentSize = compact
            ? CGSize(width: 380, height: 78)
            : CGSize(width: 480, height: 42)
        return panel.frameRect(forContentRect: CGRect(origin: .zero, size: contentSize)).size
    }

    private func applyAppearanceStyling() {
        containerView.material = .popover
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
        containerView.layer?.borderWidth = 1
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
