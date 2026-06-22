//
//  ScrollingCapturePreviewWindowService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/14.
//

import AppKit
import CoreGraphics
import SnapKit
import SwiftUI

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
    private var hostingView: NSHostingView<ScrollingCapturePreviewContentView>?
    private(set) var attachmentSide: PreviewPlacementSide?

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

    func presentPreparingPreview(selectionRect: CGRect) {
        guard let screen = screenContaining(selectionRect) else {
            dismissPreview()
            return
        }

        let placeholderSize = CGSize(width: 240, height: 160)
        guard let panelFrame = frame(for: selectionRect, on: screen, contentSize: placeholderSize) else {
            dismissPreview()
            return
        }
        attachmentSide = panelFrame.maxX <= selectionRect.minX ? .left : .right

        installContentView(
            .preparing(
                title: AppText.scrollingCapturePreviewPreparingTitle,
                message: AppText.scrollingCapturePreviewPreparingMessage
            )
        )

        AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
        panel.setFrame(panelFrame, display: true)
        applyAppearanceStyling()
        panel.orderFrontRegardless()
    }

    func presentOrUpdatePreview(image: CGImage, selectionRect: CGRect) {
        guard let screen = screenContaining(selectionRect) else {
            dismissPreview()
            return
        }

        let imageSize = CGSize(width: image.width, height: image.height)
        guard let panelFrame = frame(for: selectionRect, on: screen, contentSize: imageSize) else {
            dismissPreview()
            return
        }
        attachmentSide = panelFrame.maxX <= selectionRect.minX ? .left : .right

        installContentView(
            .image(NSImage(cgImage: image, size: imageSize))
        )

        AppThemeCoordinator.shared.applyCurrentAppearance(to: panel)
        panel.setFrame(panelFrame, display: true)
        applyAppearanceStyling()
        panel.orderFrontRegardless()
    }

    /// 关闭预览窗口
    func dismissPreview() {
        panel.orderOut(nil)
        hostingView?.removeFromSuperview()
        hostingView = nil
        attachmentSide = nil
    }

    // MARK: - Private

    private func installContentView(_ content: ScrollingCapturePreviewContent) {
        hostingView?.removeFromSuperview()

        let hostingView = NSHostingView(
            rootView: ScrollingCapturePreviewContentView(content: content)
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingView)
        hostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        self.hostingView = hostingView
    }

    private func frame(for selectionRect: CGRect, on screen: NSScreen, contentSize: CGSize) -> CGRect? {
        let visibleFrame = screen.visibleFrame
        let outerMargin: CGFloat = 24
        let gap: CGFloat = 20
        let leftAvailableWidth = selectionRect.minX - visibleFrame.minX - gap
        let rightAvailableWidth = visibleFrame.maxX - selectionRect.maxX - gap
        let placeOnLeft = leftAvailableWidth >= rightAvailableWidth
        let chosenAvailableWidth = max(placeOnLeft ? leftAvailableWidth : rightAvailableWidth, 0)
        let availableWidth = max(chosenAvailableWidth - outerMargin, 0)
        let availableHeight = max(visibleFrame.height - outerMargin * 2, 0)

        guard availableWidth >= 140, availableHeight >= 140 else {
            return nil
        }

        let scale = min(
            availableWidth / max(contentSize.width, 1),
            availableHeight / max(contentSize.height, 1),
            1
        )
        let panelSize = CGSize(
            width: max(140, floor(contentSize.width * scale)),
            height: max(140, floor(contentSize.height * scale))
        )

        let panelX: CGFloat
        if placeOnLeft {
            panelX = max(
                visibleFrame.minX + outerMargin,
                selectionRect.minX - gap - panelSize.width
            )
        } else {
            panelX = min(
                visibleFrame.maxX - outerMargin - panelSize.width,
                selectionRect.maxX + gap
            )
        }

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
