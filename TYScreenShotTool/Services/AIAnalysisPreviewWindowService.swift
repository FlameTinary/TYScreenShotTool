//
//  AIAnalysisPreviewWindowService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/18.
//

import AppKit
import SnapKit
import SwiftUI

/// AI 分析预览窗口服务
///
/// 显示 AI 分析结果的浮动面板。
@MainActor
final class AIAnalysisPreviewWindowService {
    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let containerView = NSVisualEffectView()
    private var hostingView: NSHostingView<AIAnalysisPreviewView>?

    private var onCopyAll: (() -> Void)?
    private var onCopySecondary: (() -> Void)?
    private var onRetry: (() -> Void)?
    private var onClose: (() -> Void)?

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

    func presentLoading(
        selectionRect: CGRect,
        preferredSide: PreviewPlacementSide? = nil,
        message: String? = nil,
        onClose: @escaping () -> Void
    ) {
        onCopyAll = nil
        onCopySecondary = nil
        onRetry = nil
        self.onClose = onClose
        installContentView(
            content: .loading(message: message ?? AppText.aiLoadingDeveloperError),
            onCopyAll: nil,
            onCopySecondary: nil,
            onRetry: nil,
            onClose: onClose
        )
        presentPanel(
            selectionRect: selectionRect,
            preferredSide: preferredSide
        )
    }

    func presentResult(
        result: AIAnalysisResult,
        selectionRect: CGRect,
        preferredSide: PreviewPlacementSide? = nil,
        onCopyAll: @escaping () -> Void,
        onCopyNextSteps onCopySecondary: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onCopyAll = onCopyAll
        self.onCopySecondary = onCopySecondary
        self.onRetry = onRetry
        self.onClose = onClose
        installContentView(
            content: .result(result),
            onCopyAll: onCopyAll,
            onCopySecondary: onCopySecondary,
            onRetry: onRetry,
            onClose: onClose
        )
        presentPanel(
            selectionRect: selectionRect,
            preferredSide: preferredSide
        )
    }

    func presentError(
        title: String? = nil,
        message: String,
        selectionRect: CGRect,
        preferredSide: PreviewPlacementSide? = nil,
        onRetry: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        onCopyAll = nil
        onCopySecondary = nil
        self.onRetry = onRetry
        self.onClose = onClose
        installContentView(
            content: .error(title: title ?? AppText.aiResultError, message: message),
            onCopyAll: nil,
            onCopySecondary: nil,
            onRetry: onRetry,
            onClose: onClose
        )
        presentPanel(
            selectionRect: selectionRect,
            preferredSide: preferredSide
        )
    }

    func dismiss() {
        panel.orderOut(nil)
        hostingView?.removeFromSuperview()
        hostingView = nil
        onCopyAll = nil
        onCopySecondary = nil
        onRetry = nil
        onClose = nil
    }

    private func installContentView(
        content: AIAnalysisPreviewContent,
        onCopyAll: (() -> Void)?,
        onCopySecondary: (() -> Void)?,
        onRetry: (() -> Void)?,
        onClose: @escaping () -> Void
    ) {
        hostingView?.removeFromSuperview()

        let view = AIAnalysisPreviewView(
            title: AppText.aiResultTitle,
            content: content,
            copyAllTitle: AppText.aiResultCopyAll,
            retryTitle: AppText.aiResultRetry,
            closeTitle: AppText.aiResultClose,
            onCopyAll: onCopyAll,
            onCopySecondary: onCopySecondary,
            onRetry: onRetry,
            onClose: onClose
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingView)
        hostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        self.hostingView = hostingView
    }

    private func presentPanel(
        selectionRect: CGRect,
        preferredSide: PreviewPlacementSide?
    ) {
        guard let screen = screenContaining(selectionRect) else {
            dismiss()
            return
        }

        let panelFrame = frame(
            for: selectionRect,
            on: screen,
            preferredSide: preferredSide
        )
        AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
        panel.setFrame(panelFrame, display: true)
        applyAppearanceStyling()
        panel.orderFrontRegardless()
    }

    private func applyAppearanceStyling() {
        containerView.material = .popover
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
    }

    private func frame(
        for selectionRect: CGRect,
        on screen: NSScreen,
        preferredSide: PreviewPlacementSide?
    ) -> CGRect {
        let visibleFrame = screen.visibleFrame
        let outerMargin: CGFloat = 24
        let gap: CGFloat = 20
        let minWidth: CGFloat = 320
        let maxWidth: CGFloat = 420
        let minHeight: CGFloat = 260
        let maxHeight: CGFloat = 480

        let leftAvailableWidth = selectionRect.minX - visibleFrame.minX - gap
        let rightAvailableWidth = visibleFrame.maxX - selectionRect.maxX - gap
        let leftEffectiveWidth = max(leftAvailableWidth - outerMargin, 0)
        let rightEffectiveWidth = max(rightAvailableWidth - outerMargin, 0)
        let defaultPlaceOnLeft = leftAvailableWidth >= rightAvailableWidth

        let preferredPlaceOnLeft: Bool?
        switch preferredSide {
        case .left:
            preferredPlaceOnLeft = true
        case .right:
            preferredPlaceOnLeft = false
        case nil:
            preferredPlaceOnLeft = nil
        }

        let placeOnLeft: Bool
        if let preferredPlaceOnLeft {
            let preferredWidth = preferredPlaceOnLeft ? leftEffectiveWidth : rightEffectiveWidth
            let oppositeWidth = preferredPlaceOnLeft ? rightEffectiveWidth : leftEffectiveWidth
            if preferredWidth >= minWidth || preferredWidth >= oppositeWidth {
                placeOnLeft = preferredPlaceOnLeft
            } else {
                placeOnLeft = preferredPlaceOnLeft == false
            }
        } else {
            placeOnLeft = defaultPlaceOnLeft
        }

        let availableWidth = placeOnLeft ? leftEffectiveWidth : rightEffectiveWidth
        let availableHeight = max(visibleFrame.height - outerMargin * 2, 0)

        let panelWidth = min(max(availableWidth, minWidth), maxWidth)
        let panelHeight = min(max(availableHeight * 0.52, minHeight), maxHeight)

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
