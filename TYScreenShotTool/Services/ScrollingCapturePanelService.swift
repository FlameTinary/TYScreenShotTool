//
//  ScrollingCapturePanelService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/14.
//

import AppKit
import Foundation
import SnapKit
import SwiftUI

@MainActor
final class ScrollingCapturePanelService {
    var onCopyRequested: (() -> Void)?
    var onSaveRequested: (() -> Void)?
    var onCancelRequested: (() -> Void)?
    var onOCRRequested: (() -> Void)?
    var onAIRequested: ((AIAnalysisMode) -> Void)?

    private var panel: ScrollingCapturePanel?
    private let containerView = NSVisualEffectView()
    private var hostingView: NSHostingView<ScrollingCaptureControlPanelView>?

    /// 显示长截图控制面板
    ///
    /// - Parameters:
    ///   - selectionRect: 当前选择的区域
    ///   - screen: 所在屏幕
    func presentCapturePanel(selectionRect: CGRect, on screen: NSScreen) {
        let panel = panel ?? ScrollingCapturePanel(contentRect: CGRect(x: 0, y: 0, width: 480, height: 42))
        if panel.contentView !== containerView {
            panel.contentView = containerView
        }

        containerView.material = .popover
        containerView.blendingMode = .withinWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.masksToBounds = true

        installContentView()

        let panelSize = measuredPanelFrameSize(for: panel)
        panel.setFrame(originRect(for: panelSize, selectionRect: selectionRect, on: screen), display: true)

        AppThemeCoordinator.shared.registerRefreshHandler(for: self) { [weak self] in
            guard let self, let panel = self.panel else {
                return
            }

            AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
            self.applyAppearanceStyling()
        }

        AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
        applyAppearanceStyling()
        panel.orderFrontRegardless()

        self.panel = panel
    }

    /// 关闭面板
    func dismissPanel() {
        AppThemeCoordinator.shared.unregisterRefreshHandler(for: self)
        panel?.orderOut(nil)
        hostingView?.removeFromSuperview()
        hostingView = nil
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

    private func installContentView() {
        hostingView?.removeFromSuperview()

        let hostingView = NSHostingView(rootView: makeRootView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingView)
        hostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        self.hostingView = hostingView
    }

    private func measuredPanelFrameSize(for panel: NSPanel) -> CGSize {
        let minWidth: CGFloat = 360
        let maxWidth: CGFloat = 560
        let minHeight: CGFloat = 42
        let maxHeight: CGFloat = 120

        let unconstrainedSize = measuredContentSize()
        let clampedWidth = min(max(ceil(unconstrainedSize.width), minWidth), maxWidth)
        let fittedSize = measuredContentSize(constrainedToWidth: clampedWidth)
        let clampedHeight = min(max(ceil(fittedSize.height), minHeight), maxHeight)

        let contentSize = CGSize(width: clampedWidth, height: clampedHeight)
        return panel.frameRect(forContentRect: CGRect(origin: .zero, size: contentSize)).size
    }

    private func makeRootView() -> ScrollingCaptureControlPanelView {
        ScrollingCaptureControlPanelView(
            isOCREnabled: onOCRRequested != nil,
            isAIEnabled: onAIRequested != nil,
            onCancel: { [weak self] in self?.onCancelRequested?() },
            onOCR: { [weak self] in self?.onOCRRequested?() },
            onAISelected: { [weak self] mode in self?.onAIRequested?(mode) },
            onSave: { [weak self] in self?.onSaveRequested?() },
            onCopy: { [weak self] in self?.onCopyRequested?() }
        )
    }

    private func measuredContentSize(constrainedToWidth width: CGFloat? = nil) -> CGSize {
        if let width {
            let hostingView = NSHostingView(
                rootView: makeRootView().frame(width: width, alignment: .center)
            )
            hostingView.frame = CGRect(x: 0, y: 0, width: width, height: 1)
            hostingView.layoutSubtreeIfNeeded()
            return hostingView.fittingSize
        }

        let hostingView = NSHostingView(rootView: makeRootView())
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize
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
