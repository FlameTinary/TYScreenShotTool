//
//  ScrollingCapturePreviewWindowService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/14.
//

import AppKit
import CoreGraphics

@MainActor
final class ScrollingCapturePreviewWindowService {
    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let containerView = NSVisualEffectView()
    private let imageView = NSImageView()
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

        containerView.material = .hudWindow
        containerView.blendingMode = .withinWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 14
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter

        panel.contentView = containerView
        containerView.addSubview(imageView)
    }

    func presentOrUpdatePreview(image: CGImage, selectionRect: CGRect) {
        guard let screen = screenContaining(selectionRect) else {
            dismissPreview()
            return
        }

        let visibleFrame = screen.visibleFrame
        let outerMargin: CGFloat = 24
        let gap: CGFloat = 20
        let leftAvailableWidth = selectionRect.minX - visibleFrame.minX - gap
        let rightAvailableWidth = visibleFrame.maxX - selectionRect.maxX - gap
        let placeOnLeft = leftAvailableWidth >= rightAvailableWidth
        attachmentSide = placeOnLeft ? .left : .right
        let chosenAvailableWidth = max(placeOnLeft ? leftAvailableWidth : rightAvailableWidth, 0)
        let availableWidth = max(chosenAvailableWidth - outerMargin, 0)
        let availableHeight = max(visibleFrame.height - outerMargin * 2, 0)

        guard availableWidth >= 140, availableHeight >= 140 else {
            dismissPreview()
            return
        }

        let imageSize = CGSize(width: image.width, height: image.height)
        let scale = min(
            availableWidth / max(imageSize.width, 1),
            availableHeight / max(imageSize.height, 1),
            1
        )
        let previewSize = CGSize(
            width: max(140, floor(imageSize.width * scale)),
            height: max(140, floor(imageSize.height * scale))
        )

        let panelX: CGFloat
        if placeOnLeft {
            panelX = max(
                visibleFrame.minX + outerMargin,
                selectionRect.minX - gap - previewSize.width
            )
        } else {
            panelX = min(
                visibleFrame.maxX - outerMargin - previewSize.width,
                selectionRect.maxX + gap
            )
        }

        let panelY = min(
            max(selectionRect.midY - previewSize.height / 2, visibleFrame.minY + outerMargin),
            visibleFrame.maxY - outerMargin - previewSize.height
        )

        panel.setFrame(
            CGRect(origin: CGPoint(x: panelX, y: panelY), size: previewSize),
            display: true
        )

        containerView.frame = CGRect(origin: .zero, size: previewSize)
        imageView.frame = containerView.bounds.insetBy(dx: 12, dy: 12)
        imageView.image = NSImage(cgImage: image, size: imageSize)
        panel.orderFrontRegardless()
    }

    func dismissPreview() {
        panel.orderOut(nil)
        imageView.image = nil
        attachmentSide = nil
    }

    private func screenContaining(_ rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.contains(CGPoint(x: rect.midX, y: rect.midY))
        }
    }
}
