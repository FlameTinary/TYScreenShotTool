//
//  ScrollingCapturePreviewWindowService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/14.
//

import AppKit
import CoreGraphics
import SnapKit

/// 长截图预览窗口服务
///
/// 在屏幕边缘显示长截图实时预览。
@MainActor
final class ScrollingCapturePreviewWindowService {
    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let containerView = NSVisualEffectView()
    private let contentView = ScrollingCapturePreviewContentView()
    private(set) var attachmentSide: PreviewPlacementSide?

    // MARK: - 预览窗口尺寸常量

    /// 预览窗口最小宽度
    private let scrollingPreviewMinWidth: CGFloat = 160
    /// 预览窗口最大宽度
    private let scrollingPreviewMaxWidth: CGFloat = 280
    /// 预览窗口与避让区域之间的间距
    private let scrollingPreviewSpacing: CGFloat = 12

    init() {
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true

        containerView.material = .popover
        containerView.blendingMode = .withinWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 14
        containerView.layer?.borderWidth = 1

        panel.contentView = containerView
        containerView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

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

    func presentPreparingPreview(selectionRect: CGRect, toolbarScreenRect: CGRect = .zero) {
        guard let screen = screenContaining(selectionRect) else {
            dismissPreview()
            return
        }

        let placeholderSize = CGSize(width: 240, height: 160)
        guard let panelFrame = frame(for: selectionRect, on: screen, contentSize: placeholderSize, toolbarScreenRect: toolbarScreenRect) else {
            dismissPreview()
            return
        }
        attachmentSide = panelFrame.maxX <= selectionRect.minX ? .left : .right

        contentView.configure(
            content: .preparing(
                title: AppText.scrollingCapturePreviewPreparingTitle,
                message: AppText.scrollingCapturePreviewPreparingMessage
            )
        )

        AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
        panel.setFrame(panelFrame, display: true)
        applyAppearanceStyling()
        panel.orderFrontRegardless()
    }

    func presentOrUpdatePreview(image: CGImage, selectionRect: CGRect, toolbarScreenRect: CGRect = .zero) {
        guard let screen = screenContaining(selectionRect) else {
            dismissPreview()
            return
        }

        let imageSize = CGSize(width: image.width, height: image.height)
        guard let panelFrame = frame(for: selectionRect, on: screen, contentSize: imageSize, toolbarScreenRect: toolbarScreenRect) else {
            dismissPreview()
            return
        }
        attachmentSide = panelFrame.maxX <= selectionRect.minX ? .left : .right

        contentView.configure(
            content: .image(NSImage(cgImage: image, size: imageSize))
        )

        AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
        panel.setFrame(panelFrame, display: true)
        applyAppearanceStyling()
        panel.orderFrontRegardless()
    }

    /// 关闭预览窗口
    func dismissPreview() {
        panel.orderOut(nil)
        attachmentSide = nil
    }

    // MARK: - Private

    private func frame(
        for selectionRect: CGRect,
        on screen: NSScreen,
        contentSize: CGSize,
        toolbarScreenRect: CGRect
    ) -> CGRect? {
        let visibleFrame = screen.visibleFrame
        let outerMargin: CGFloat = 24

        // 计算避让区域：selectionRect 和工具栏的合并区域，加入安全间距
        let occupiedRect = selectionRect.union(toolbarScreenRect)
        let avoidRect = occupiedRect.insetBy(
            dx: -scrollingPreviewSpacing,
            dy: -scrollingPreviewSpacing
        )

        // 计算左右可用空间
        let leftAvailableWidth = avoidRect.minX - visibleFrame.minX
        let rightAvailableWidth = visibleFrame.maxX - avoidRect.maxX

        let canPlaceLeft = leftAvailableWidth >= scrollingPreviewMinWidth
        let canPlaceRight = rightAvailableWidth >= scrollingPreviewMinWidth

        let placeOnRight: Bool
        let selectedAvailableWidth: CGFloat

        if canPlaceLeft && canPlaceRight {
            // 两侧都能放，选择空间更大的一侧
            placeOnRight = rightAvailableWidth >= leftAvailableWidth
            selectedAvailableWidth = placeOnRight ? rightAvailableWidth : leftAvailableWidth
        } else if canPlaceRight {
            // 只有右侧能放
            placeOnRight = true
            selectedAvailableWidth = rightAvailableWidth
        } else if canPlaceLeft {
            // 只有左侧能放
            placeOnRight = false
            selectedAvailableWidth = leftAvailableWidth
        } else {
            // 左右都放不下最小宽度，选择空间更大的一侧，使用最小宽度
            placeOnRight = rightAvailableWidth >= leftAvailableWidth
            selectedAvailableWidth = max(leftAvailableWidth, rightAvailableWidth)
        }

        // 计算目标宽度
        let targetWidth: CGFloat
        if selectedAvailableWidth >= scrollingPreviewMinWidth {
            targetWidth = min(scrollingPreviewMaxWidth, selectedAvailableWidth)
        } else {
            targetWidth = scrollingPreviewMinWidth
        }

        // 可用高度
        let availableHeight = max(visibleFrame.height - outerMargin * 2, 0)

        guard targetWidth >= 140, availableHeight >= 140 else {
            return nil
        }

        // 等比例缩放内容以适应目标尺寸
        let scale = min(
            targetWidth / max(contentSize.width, 1),
            availableHeight / max(contentSize.height, 1),
            1
        )
        let panelSize = CGSize(
            width: max(140, floor(contentSize.width * scale)),
            height: max(140, floor(contentSize.height * scale))
        )

        // 计算 X 坐标
        let panelX: CGFloat
        if placeOnRight {
            let desiredX = avoidRect.maxX + scrollingPreviewSpacing
            panelX = min(desiredX, visibleFrame.maxX - outerMargin - panelSize.width)
        } else {
            let desiredX = avoidRect.minX - scrollingPreviewSpacing - panelSize.width
            panelX = max(desiredX, visibleFrame.minX + outerMargin)
        }

        // Y 坐标基于 selectionRect 垂直居中（沿用现有规则）
        let panelY = min(
            max(selectionRect.midY - panelSize.height / 2, visibleFrame.minY + outerMargin),
            visibleFrame.maxY - outerMargin - panelSize.height
        )

        return CGRect(origin: CGPoint(x: panelX, y: panelY), size: panelSize)
    }

    private func screenContaining(_ rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.contains(CGPoint(x: rect.midX, y: rect.midY))
        }
    }

    private func applyAppearanceStyling() {
        containerView.material = .popover
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
    }
}
