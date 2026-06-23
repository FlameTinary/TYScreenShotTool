//
//  OCRPreviewWindowService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/18.
//

import AppKit
import SnapKit

/// OCR 预览窗口服务
///
/// 显示 OCR 识别结果的浮动面板。
@MainActor
final class OCRPreviewWindowService {
    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let containerView = NSVisualEffectView()
    private let contentView = OCRPreviewContentView()
    private var onCopy: (() -> Void)?
    private var onCancel: (() -> Void)?

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

    /// 显示 OCR 结果
    ///
    /// - Parameters:
    ///   - text: 识别的文本
    ///   - selectionRect: 选择区域
    ///   - preferredSide: 首选显示位置
    ///   - onCopy: 复制按钮回调
    ///   - onCancel: 取消按钮回调
    func present(
        text: String,
        selectionRect: CGRect,
        preferredSide: PreviewPlacementSide? = nil,
        onCopy: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        guard let screen = screenContaining(selectionRect) else {
            dismiss()
            return
        }

        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayText = normalizedText.isEmpty ? AppText.ocrEmpty : text
        self.onCopy = onCopy
        self.onCancel = onCancel

        contentView.onCopy = onCopy
        contentView.onCancel = onCancel
        contentView.configure(
            title: AppText.ocrWindowTitle,
            text: displayText,
            isCopyEnabled: normalizedText.isEmpty == false,
            copyTitle: AppText.captureCopy,
            cancelTitle: AppText.captureCancel
        )

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

    func dismiss() {
        panel.orderOut(nil)
        onCopy = nil
        onCancel = nil
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
        let minWidth: CGFloat = 260
        let maxWidth: CGFloat = 360
        let minHeight: CGFloat = 220
        let maxHeight: CGFloat = 420

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

        let panelWidth = min(max(max(availableWidth, minWidth), minWidth), maxWidth)
        let panelHeight = min(max(max(availableHeight * 0.45, minHeight), minHeight), maxHeight)

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
