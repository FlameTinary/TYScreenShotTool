//
//  CaptureOverlayView.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/5.
//

import AppKit

final class CaptureOverlayView: NSView {
    var onCancel: (() -> Void)?
    var onDragStarted: (() -> Void)?
    var onSelection: ((CGRect) -> Void)?
    var onCopyRequested: ((CapturePreviewStyle) -> Void)?
    var onSaveRequested: ((CapturePreviewStyle) -> Void)?

    private var dragStartPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isDragging = false
    private var mode: Mode = .selection
    private var previewSelectionRect: CGRect?
    private var previewStyle = CapturePreviewStyle.default

    private let previewContainerView = NSView()
    private let previewClipView = NSView()
    private let previewImageView = NSImageView()
    private let topBarContainerView = NSVisualEffectView()
    private let sizeLabel = NSTextField(labelWithString: "")
    private let roundedToggle = NSButton(checkboxWithTitle: "圆角", target: nil, action: nil)
    private let shadowToggle = NSButton(checkboxWithTitle: "阴影", target: nil, action: nil)
    private let toolbarContainerView = NSVisualEffectView()
    private let copyButton = NSButton(title: "复制", target: nil, action: nil)
    private let saveButton = NSButton(title: "保存", target: nil, action: nil)
    private let cancelButton = NSButton(title: "取消", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configurePreviewViews()
        configureTopBar()
        configureToolbar()
        resetToSelectionMode()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        let activeRect: CGRect?
        switch mode {
        case .selection:
            activeRect = selectionRect
        case .preview:
            activeRect = previewSelectionRect
        }

        if let activeRect {
            let overlayPath = NSBezierPath(rect: bounds)
            let cutoutPath = cutoutPath(for: activeRect)
            overlayPath.append(cutoutPath)
            overlayPath.windingRule = .evenOdd
            NSColor.black.withAlphaComponent(0.35).setFill()
            overlayPath.fill()
        } else {
            NSColor.black.withAlphaComponent(0.35).setFill()
            bounds.fill()
        }

        switch mode {
        case .selection:
            guard let selectionRect else {
                return
            }

            NSColor.white.setStroke()
            let path = NSBezierPath(rect: selectionRect)
            path.lineWidth = 2
            path.stroke()
        case .preview:
            guard let previewSelectionRect else {
                return
            }

            NSColor.white.setStroke()
            let path = NSBezierPath(rect: previewSelectionRect)
            path.lineWidth = 2
            path.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard mode == .selection else {
            super.mouseDown(with: event)
            return
        }

        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        dragStartPoint = point
        currentPoint = point
        isDragging = true
        onDragStarted?()
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard mode == .selection else {
            super.mouseDragged(with: event)
            return
        }

        guard isDragging else {
            return
        }

        let point = constrainedPoint(for: event)
        currentPoint = point
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard mode == .selection else {
            super.mouseUp(with: event)
            return
        }

        guard isDragging else {
            return
        }

        currentPoint = constrainedPoint(for: event)
        isDragging = false
        needsDisplay = true

        if let selectionRect {
            onSelection?(selectionRect)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        super.keyDown(with: event)
    }

    override func layout() {
        super.layout()
        layoutPreviewInterface()
    }

    func showSelectionPreview(selectionRect: CGRect) {
        mode = .preview
        previewSelectionRect = selectionRect
        previewImageView.image = nil
        sizeLabel.stringValue = "\(Int(selectionRect.width)) x \(Int(selectionRect.height))"
        previewStyle = .default
        roundedToggle.state = .off
        shadowToggle.state = .off

        previewContainerView.isHidden = false
        topBarContainerView.isHidden = false
        toolbarContainerView.isHidden = false

        updatePreviewAppearance()
        needsLayout = true
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    func resetToSelectionMode() {
        mode = .selection
        dragStartPoint = nil
        currentPoint = nil
        isDragging = false
        previewSelectionRect = nil
        previewImageView.image = nil
        previewContainerView.isHidden = true
        topBarContainerView.isHidden = true
        toolbarContainerView.isHidden = true
        needsDisplay = true
    }

    private var selectionRect: CGRect? {
        guard let dragStartPoint, let currentPoint else {
            return nil
        }

        let x = min(dragStartPoint.x, currentPoint.x)
        let y = min(dragStartPoint.y, currentPoint.y)
        let width = abs(currentPoint.x - dragStartPoint.x)
        let height = abs(currentPoint.y - dragStartPoint.y)

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func constrainedPoint(for event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)

        return CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }

    private func configurePreviewViews() {
        previewContainerView.wantsLayer = true
        previewContainerView.layer?.borderWidth = 2
        previewContainerView.layer?.borderColor = NSColor.white.cgColor
        previewContainerView.layer?.backgroundColor = NSColor.clear.cgColor

        previewClipView.wantsLayer = true
        previewClipView.layer?.masksToBounds = true
        previewClipView.autoresizingMask = [.width, .height]

        previewImageView.imageScaling = .scaleAxesIndependently
        previewImageView.autoresizingMask = [.width, .height]

        previewClipView.addSubview(previewImageView)
        previewContainerView.addSubview(previewClipView)
        addSubview(previewContainerView)
    }

    private func configureTopBar() {
        topBarContainerView.material = .hudWindow
        topBarContainerView.blendingMode = .withinWindow
        topBarContainerView.state = .active
        topBarContainerView.wantsLayer = true
        topBarContainerView.layer?.cornerRadius = 10

        sizeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        sizeLabel.textColor = .white

        roundedToggle.target = self
        roundedToggle.action = #selector(toggleRoundedCorners)
        roundedToggle.contentTintColor = .white

        shadowToggle.target = self
        shadowToggle.action = #selector(toggleShadow)
        shadowToggle.contentTintColor = .white
        shadowToggle.state = .on
        topBarContainerView.addSubview(sizeLabel)
        topBarContainerView.addSubview(roundedToggle)
        topBarContainerView.addSubview(shadowToggle)
        addSubview(topBarContainerView)
    }

    private func configureToolbar() {
        toolbarContainerView.material = .hudWindow
        toolbarContainerView.blendingMode = .withinWindow
        toolbarContainerView.state = .active
        toolbarContainerView.wantsLayer = true
        toolbarContainerView.layer?.cornerRadius = 12

        copyButton.target = self
        copyButton.action = #selector(requestCopy)
        saveButton.target = self
        saveButton.action = #selector(requestSave)
        cancelButton.target = self
        cancelButton.action = #selector(requestCancel)

        [copyButton, saveButton, cancelButton].forEach { button in
            button.bezelStyle = .rounded
        }
        toolbarContainerView.addSubview(copyButton)
        toolbarContainerView.addSubview(saveButton)
        toolbarContainerView.addSubview(cancelButton)
        addSubview(toolbarContainerView)
    }

    private func layoutPreviewInterface() {
        guard mode == .preview, let previewSelectionRect else {
            return
        }

        previewContainerView.frame = previewSelectionRect
        previewClipView.frame = previewContainerView.bounds
        previewImageView.frame = previewClipView.bounds

        sizeLabel.sizeToFit()
        roundedToggle.sizeToFit()
        shadowToggle.sizeToFit()

        let topBarPaddingX: CGFloat = 12
        let topBarPaddingY: CGFloat = 6
        let topBarSpacing: CGFloat = 10
        let topBarContentHeight = max(
            sizeLabel.frame.height,
            roundedToggle.frame.height,
            shadowToggle.frame.height
        )
        let topBarWidth = topBarPaddingX * 2
            + sizeLabel.frame.width
            + topBarSpacing
            + roundedToggle.frame.width
            + topBarSpacing
            + shadowToggle.frame.width
        let topBarHeight = topBarPaddingY * 2 + topBarContentHeight
        let topBarX = min(
            max(previewSelectionRect.minX, 24),
            bounds.maxX - topBarWidth - 24
        )
        let topBarY = min(
            bounds.maxY - topBarHeight - 24,
            previewSelectionRect.maxY + 16
        )
        topBarContainerView.frame = CGRect(
            x: topBarX,
            y: topBarY,
            width: topBarWidth,
            height: topBarHeight
        )

        var currentTopBarX = topBarPaddingX
        sizeLabel.frame.origin = CGPoint(
            x: currentTopBarX,
            y: (topBarHeight - sizeLabel.frame.height) / 2
        )
        currentTopBarX += sizeLabel.frame.width + topBarSpacing
        roundedToggle.frame.origin = CGPoint(
            x: currentTopBarX,
            y: (topBarHeight - roundedToggle.frame.height) / 2
        )
        currentTopBarX += roundedToggle.frame.width + topBarSpacing
        shadowToggle.frame.origin = CGPoint(
            x: currentTopBarX,
            y: (topBarHeight - shadowToggle.frame.height) / 2
        )

        copyButton.sizeToFit()
        saveButton.sizeToFit()
        cancelButton.sizeToFit()

        let toolbarPaddingX: CGFloat = 12
        let toolbarPaddingY: CGFloat = 6
        let toolbarSpacing: CGFloat = 12
        let toolbarContentHeight = max(
            copyButton.frame.height,
            saveButton.frame.height,
            cancelButton.frame.height
        )
        let toolbarWidth = toolbarPaddingX * 2
            + copyButton.frame.width
            + toolbarSpacing
            + saveButton.frame.width
            + toolbarSpacing
            + cancelButton.frame.width
        let toolbarHeight = toolbarPaddingY * 2 + toolbarContentHeight
        let toolbarX = min(
            max(previewSelectionRect.midX - (toolbarWidth / 2), 24),
            bounds.maxX - toolbarWidth - 24
        )
        let toolbarY = max(24, previewSelectionRect.minY - toolbarHeight - 24)
        toolbarContainerView.frame = CGRect(
            x: toolbarX,
            y: toolbarY,
            width: toolbarWidth,
            height: toolbarHeight
        )

        var currentToolbarX = toolbarPaddingX
        copyButton.frame.origin = CGPoint(
            x: currentToolbarX,
            y: (toolbarHeight - copyButton.frame.height) / 2
        )
        currentToolbarX += copyButton.frame.width + toolbarSpacing
        saveButton.frame.origin = CGPoint(
            x: currentToolbarX,
            y: (toolbarHeight - saveButton.frame.height) / 2
        )
        currentToolbarX += saveButton.frame.width + toolbarSpacing
        cancelButton.frame.origin = CGPoint(
            x: currentToolbarX,
            y: (toolbarHeight - cancelButton.frame.height) / 2
        )
    }

    private func updatePreviewAppearance() {
        previewClipView.layer?.cornerRadius = previewStyle.showsRoundedCorners ? 12 : 0
        previewContainerView.layer?.shadowColor = NSColor.black.cgColor
        previewContainerView.layer?.shadowOpacity = previewStyle.showsShadow ? 0.25 : 0
        previewContainerView.layer?.shadowRadius = previewStyle.showsShadow ? 12 : 0
        previewContainerView.layer?.shadowOffset = CGSize(width: 0, height: -4)
        needsDisplay = true
    }

    @objc
    private func toggleRoundedCorners() {
        previewStyle.showsRoundedCorners = roundedToggle.state == .on
        updatePreviewAppearance()
    }

    @objc
    private func toggleShadow() {
        previewStyle.showsShadow = shadowToggle.state == .on
        updatePreviewAppearance()
    }

    @objc
    private func requestCopy() {
        onCopyRequested?(previewStyle)
    }

    @objc
    private func requestSave() {
        onSaveRequested?(previewStyle)
    }

    @objc
    private func requestCancel() {
        onCancel?()
    }

    private func cutoutPath(for rect: CGRect) -> NSBezierPath {
        if mode == .preview && previewStyle.showsRoundedCorners {
            return NSBezierPath(
                roundedRect: rect,
                xRadius: 12,
                yRadius: 12
            )
        }

        return NSBezierPath(rect: rect)
    }

    private enum Mode {
        case selection
        case preview
    }
}
