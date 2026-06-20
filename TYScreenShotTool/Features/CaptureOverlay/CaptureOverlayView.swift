//
//  CaptureOverlayView.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/5.
//

import AppKit

final class CaptureOverlayView: NSView {
    private static let maximumCornerRadius: Double = 100

    var onCancel: (() -> Void)?
    var onDragStarted: (() -> Void)?
    var onSelection: ((CGRect) -> Void)?
    var onWindowSelectionConfirmed: ((WindowSelectionCandidate) -> Void)?
    var onPreviewSelectionChanged: ((CGRect) -> Void)?
    var onCopyRequested: ((CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
    var onSaveRequested: ((CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
    var onOCRRequested: ((CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
    var onAIRequested: ((AIAnalysisMode, CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
    var onPinRequested: ((CapturePreviewStyle, [CaptureAnnotation]) -> Void)?
    var onLongCaptureRequested: (([CaptureAnnotation]) -> Void)?

    private static let edgeHitThickness: CGFloat = 8
    private static let cornerHitSize: CGFloat = 12
    private static let minimumSelectionWidth: CGFloat = 40
    private static let minimumSelectionHeight: CGFloat = 40
    private static let dragActivationDistance: CGFloat = 4

    var windowCandidateProvider: ((CGPoint) -> WindowSelectionCandidate?)?

    private var dragStartPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isDragging = false
    private var hoveredWindowCandidate: WindowSelectionCandidate?
    private var mouseDownPoint: CGPoint?
    private var mouseDownWindowCandidate: WindowSelectionCandidate?
    private var isPendingWindowClickConfirmation = false
    private var previewSelectionLocked = false
    private var cursorTrackingArea: NSTrackingArea?
    private var hoverInteractionTarget: PreviewInteractionTarget = .none
    private var activeInteractionTarget: PreviewInteractionTarget = .none
    private var interactionStartMousePoint: CGPoint?
    private var interactionStartSelectionRect: CGRect?
    private var mode: Mode = .selection
    private var isLongCaptureGuideMode = false
    private var suppressFrozenBackground = false
    private var previewSelectionRect: CGRect?
    private var previewStyle = CapturePreviewStyle.default
    var selectionSourceScreenImage: CGImage? {
        didSet {
            needsDisplay = true
        }
    }
    private var previewSourceScreenImage: CGImage?
    private var previewSourceScreenFrame: CGRect?

    private let previewContainerView = NSView()
    private let previewClipView = NSView()
    private let previewImageView = NSImageView()
    private let annotationCanvasView = CaptureAnnotationCanvasView()
    private let topBarContainerView = NSVisualEffectView()
    private let sizeLabel = NSTextField(labelWithString: "")
    private let cornerRadiusLabel = NSTextField(labelWithString: "圆角")
    private let cornerRadiusSlider = NSSlider(value: 0, minValue: 0, maxValue: maximumCornerRadius, target: nil, action: nil)
    private let shadowToggle = NSButton(checkboxWithTitle: "阴影", target: nil, action: nil)
    private let toolbarContainerView = NSVisualEffectView()
    private var annotationToolButtons: [AnnotationTool: NSButton] = [:]
    private let undoButton = NSButton(title: "撤销", target: nil, action: nil)
    private let longCaptureButton = NSButton(title: "长截图", target: nil, action: nil)
    private let ocrButton = NSButton(title: "OCR", target: nil, action: nil)
    private let aiButton = NSButton(title: "AI", target: nil, action: nil)
    private let pinButton = NSButton(title: "Pin", target: nil, action: nil)
    private let copyButton = NSButton(title: "复制", target: nil, action: nil)
    private let saveButton = NSButton(title: "保存", target: nil, action: nil)
    private let cancelButton = NSButton(title: "取消", target: nil, action: nil)
    private var currentAnnotationTool: AnnotationTool?

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
        window?.acceptsMouseMovedEvents = true
    }

    override func updateTrackingAreas() {
        if let cursorTrackingArea {
            removeTrackingArea(cursorTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        cursorTrackingArea = trackingArea

        super.updateTrackingAreas()
    }

    override func draw(_ dirtyRect: NSRect) {
        if selectionSourceScreenImage != nil, suppressFrozenBackground == false {
            drawSelectionBackground(in: dirtyRect)
        }

        let activeRect: CGRect?
        switch mode {
        case .selection:
            activeRect = selectionRect ?? hoveredWindowCandidate?.frame
        case .preview:
            activeRect = previewSelectionRect
        }

        if isLongCaptureGuideMode == false {
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
        }

        switch mode {
        case .selection:
            guard let selectionRect = selectionRect ?? hoveredWindowCandidate?.frame else {
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
        if mode == .preview {
            handlePreviewMouseDown(with: event)
            return
        }

        guard mode == .selection else {
            super.mouseDown(with: event)
            return
        }

        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        refreshHoveredWindowCandidate(at: point)
        mouseDownPoint = point
        mouseDownWindowCandidate = hoveredWindowCandidate
        isPendingWindowClickConfirmation = hoveredWindowCandidate != nil
        updateCursor(for: point)
    }

    override func mouseDragged(with event: NSEvent) {
        if mode == .preview {
            handlePreviewMouseDragged(with: event)
            return
        }

        guard mode == .selection else {
            super.mouseDragged(with: event)
            return
        }

        let point = constrainedPoint(for: event)

        if isDragging == false, let startPoint = mouseDownPoint {
            let deltaX = point.x - startPoint.x
            let deltaY = point.y - startPoint.y
            let distance = hypot(deltaX, deltaY)

            guard distance >= Self.dragActivationDistance else {
                updateCursor(for: point)
                return
            }

            dragStartPoint = startPoint
            currentPoint = point
            isDragging = true
            isPendingWindowClickConfirmation = false
            hoveredWindowCandidate = nil
            onDragStarted?()
            needsDisplay = true
            updateCursor(for: point)
            return
        }

        guard isDragging else {
            updateCursor(for: point)
            return
        }

        currentPoint = point
        needsDisplay = true
        updateCursor(for: point)
    }

    override func mouseUp(with event: NSEvent) {
        if mode == .preview {
            handlePreviewMouseUp(with: event)
            return
        }

        guard mode == .selection else {
            super.mouseUp(with: event)
            return
        }

        let point = constrainedPoint(for: event)

        defer {
            mouseDownPoint = nil
            mouseDownWindowCandidate = nil
            isPendingWindowClickConfirmation = false
        }

        if isDragging {
            currentPoint = point
            isDragging = false
            needsDisplay = true

            if let selectionRect {
                onSelection?(selectionRect)
            }

            updateCursor(for: currentPoint ?? .zero)
            return
        }

        if isPendingWindowClickConfirmation, let windowCandidate = mouseDownWindowCandidate {
            onWindowSelectionConfirmed?(windowCandidate)
            return
        }

        refreshHoveredWindowCandidate(at: point)
        updateCursor(for: point)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        super.keyDown(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        refreshHoveredWindowCandidate(at: point)
        updateCursor(for: point)
    }

    override func cursorUpdate(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        refreshHoveredWindowCandidate(at: point)
        updateCursor(for: point)
    }

    override func layout() {
        super.layout()
        layoutPreviewInterface()
    }

    func showSelectionPreview(selectionRect: CGRect, sourceScreenImage: CGImage?, screenFrame: CGRect) {
        mode = .preview
        isLongCaptureGuideMode = false
        suppressFrozenBackground = false
        previewSelectionRect = selectionRect
        previewSourceScreenImage = sourceScreenImage
        previewSourceScreenFrame = screenFrame
        previewImageView.image = nil
        sizeLabel.stringValue = "\(Int(selectionRect.width)) x \(Int(selectionRect.height))"
        previewStyle = .default
        cornerRadiusSlider.doubleValue = 0
        shadowToggle.state = .off
        currentAnnotationTool = nil
        annotationCanvasView.resetAnnotations()
        updateAnnotationToolSelection()

        previewContainerView.isHidden = false
        topBarContainerView.isHidden = false
        toolbarContainerView.isHidden = false
        aiButton.isEnabled = true

        updateAnnotationSourceImage()
        updatePreviewAppearance()
        needsLayout = true
        needsDisplay = true
        window?.makeFirstResponder(self)
        updateCursor(for: selectionRect.origin)
    }

    func enterLongCaptureGuideMode() {
        guard mode == .preview, previewSelectionRect != nil else {
            return
        }

        isLongCaptureGuideMode = true
        suppressFrozenBackground = true
        previewContainerView.isHidden = true
        topBarContainerView.isHidden = true
        toolbarContainerView.isHidden = true
        needsDisplay = true
    }

    func exitLongCaptureGuideMode() {
        guard mode == .preview else {
            return
        }

        isLongCaptureGuideMode = false
        suppressFrozenBackground = false
        previewContainerView.isHidden = false
        topBarContainerView.isHidden = false
        toolbarContainerView.isHidden = false
        needsLayout = true
        needsDisplay = true
    }

    func resetToSelectionMode() {
        mode = .selection
        isLongCaptureGuideMode = false
        suppressFrozenBackground = false
        dragStartPoint = nil
        currentPoint = nil
        isDragging = false
        hoveredWindowCandidate = nil
        mouseDownPoint = nil
        mouseDownWindowCandidate = nil
        isPendingWindowClickConfirmation = false
        hoverInteractionTarget = .none
        activeInteractionTarget = .none
        interactionStartMousePoint = nil
        interactionStartSelectionRect = nil
        previewSelectionLocked = false
        previewSelectionRect = nil
        selectionSourceScreenImage = nil
        previewSourceScreenImage = nil
        previewSourceScreenFrame = nil
        previewImageView.image = nil
        currentAnnotationTool = nil
        annotationCanvasView.resetAnnotations()
        annotationCanvasView.sourceImage = nil
        previewContainerView.isHidden = true
        topBarContainerView.isHidden = true
        toolbarContainerView.isHidden = true
        aiButton.isEnabled = true
        needsDisplay = true
        NSCursor.crosshair.set()
    }

    func setAIButtonEnabled(_ isEnabled: Bool) {
        aiButton.isEnabled = isEnabled
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

    private var canEditPreviewSelection: Bool {
        guard mode == .preview else {
            return false
        }

        guard previewSelectionRect != nil else {
            return false
        }

        guard currentAnnotationTool == nil else {
            return false
        }

        guard previewSelectionLocked == false else {
            return false
        }

        guard annotationCanvasView.annotations.isEmpty else {
            return false
        }

        return annotationCanvasView.hasActiveTextInput == false
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
        previewContainerView.layer?.cornerCurve = .continuous

        previewClipView.wantsLayer = true
        previewClipView.layer?.masksToBounds = true
        previewClipView.layer?.cornerCurve = .continuous
        previewClipView.autoresizingMask = [.width, .height]

        previewImageView.imageScaling = .scaleAxesIndependently
        previewImageView.autoresizingMask = [.width, .height]
        annotationCanvasView.autoresizingMask = [.width, .height]
        annotationCanvasView.wantsLayer = true
        annotationCanvasView.layer?.backgroundColor = NSColor.clear.cgColor
        annotationCanvasView.annotationsDidChange = { [weak self] annotations in
            guard let self else {
                return
            }

            if annotations.isEmpty == false {
                self.previewSelectionLocked = true
                self.updateCursorFromCurrentEvent()
            }
        }

        previewClipView.addSubview(previewImageView)
        previewClipView.addSubview(annotationCanvasView)
        previewContainerView.addSubview(previewClipView)
        addSubview(previewContainerView)
    }

    private func handlePreviewMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)

        let interactionTarget = interactionTarget(for: point)
        guard interactionTarget != .none else {
            super.mouseDown(with: event)
            return
        }

        activeInteractionTarget = interactionTarget
        interactionStartMousePoint = point
        interactionStartSelectionRect = previewSelectionRect
        needsDisplay = true
        updateCursor(for: point)
    }

    private func handlePreviewMouseDragged(with event: NSEvent) {
        guard
            activeInteractionTarget != .none,
            let startMousePoint = interactionStartMousePoint,
            let startSelectionRect = interactionStartSelectionRect
        else {
            super.mouseDragged(with: event)
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        previewSelectionRect = updatedPreviewSelectionRect(
            from: startSelectionRect,
            startPoint: startMousePoint,
            currentPoint: point,
            interactionTarget: activeInteractionTarget
        )
        updateAnnotationSourceImage()
        updateSizeLabel()
        needsLayout = true
        needsDisplay = true
        updateCursor(for: point)
    }

    private func handlePreviewMouseUp(with event: NSEvent) {
        guard activeInteractionTarget != .none else {
            super.mouseUp(with: event)
            return
        }

        activeInteractionTarget = .none
        interactionStartMousePoint = nil
        interactionStartSelectionRect = nil
        hoverInteractionTarget = interactionTarget(for: convert(event.locationInWindow, from: nil))

        if let previewSelectionRect {
            onPreviewSelectionChanged?(previewSelectionRect)
        }

        needsDisplay = true
        updateCursor(for: convert(event.locationInWindow, from: nil))
    }

    private func updatedPreviewSelectionRect(
        from rect: CGRect,
        startPoint: CGPoint,
        currentPoint: CGPoint,
        interactionTarget: PreviewInteractionTarget
    ) -> CGRect {
        let deltaX = currentPoint.x - startPoint.x
        let deltaY = currentPoint.y - startPoint.y

        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        switch interactionTarget {
        case .move:
            return constrainedMoveRect(rect.offsetBy(dx: deltaX, dy: deltaY))
        case .resizeTop:
            maxY += deltaY
        case .resizeBottom:
            minY += deltaY
        case .resizeLeft:
            minX += deltaX
        case .resizeRight:
            maxX += deltaX
        case .resizeTopLeft:
            minX += deltaX
            maxY += deltaY
        case .resizeTopRight:
            maxX += deltaX
            maxY += deltaY
        case .resizeBottomLeft:
            minX += deltaX
            minY += deltaY
        case .resizeBottomRight:
            maxX += deltaX
            minY += deltaY
        case .none:
            return rect
        }

        return constrainedResizeRect(minX: minX, maxX: maxX, minY: minY, maxY: maxY, target: interactionTarget)
    }

    private func constrainedMoveRect(_ rect: CGRect) -> CGRect {
        let constrainedX = min(max(rect.minX, bounds.minX), bounds.maxX - rect.width)
        let constrainedY = min(max(rect.minY, bounds.minY), bounds.maxY - rect.height)

        return CGRect(
            x: constrainedX,
            y: constrainedY,
            width: rect.width,
            height: rect.height
        )
    }

    private func constrainedResizeRect(
        minX: CGFloat,
        maxX: CGFloat,
        minY: CGFloat,
        maxY: CGFloat,
        target: PreviewInteractionTarget
    ) -> CGRect {
        var adjustedMinX = minX
        var adjustedMaxX = maxX
        var adjustedMinY = minY
        var adjustedMaxY = maxY

        switch target {
        case .resizeLeft, .resizeTopLeft, .resizeBottomLeft:
            adjustedMinX = min(adjustedMinX, adjustedMaxX - Self.minimumSelectionWidth)
            adjustedMinX = max(adjustedMinX, bounds.minX)
            adjustedMaxX = max(adjustedMaxX, adjustedMinX + Self.minimumSelectionWidth)
        case .resizeRight, .resizeTopRight, .resizeBottomRight:
            adjustedMaxX = max(adjustedMaxX, adjustedMinX + Self.minimumSelectionWidth)
            adjustedMaxX = min(adjustedMaxX, bounds.maxX)
            adjustedMinX = min(adjustedMinX, adjustedMaxX - Self.minimumSelectionWidth)
        case .resizeTop, .resizeBottom, .move, .none:
            break
        }

        switch target {
        case .resizeBottom, .resizeBottomLeft, .resizeBottomRight:
            adjustedMinY = min(adjustedMinY, adjustedMaxY - Self.minimumSelectionHeight)
            adjustedMinY = max(adjustedMinY, bounds.minY)
            adjustedMaxY = max(adjustedMaxY, adjustedMinY + Self.minimumSelectionHeight)
        case .resizeTop, .resizeTopLeft, .resizeTopRight:
            adjustedMaxY = max(adjustedMaxY, adjustedMinY + Self.minimumSelectionHeight)
            adjustedMaxY = min(adjustedMaxY, bounds.maxY)
            adjustedMinY = min(adjustedMinY, adjustedMaxY - Self.minimumSelectionHeight)
        case .resizeLeft, .resizeRight, .move, .none:
            break
        }

        let width = max(adjustedMaxX - adjustedMinX, Self.minimumSelectionWidth)
        let height = max(adjustedMaxY - adjustedMinY, Self.minimumSelectionHeight)

        return CGRect(
            x: adjustedMinX,
            y: adjustedMinY,
            width: width,
            height: height
        )
    }

    private func updateCursorFromCurrentEvent() {
        guard let window else {
            NSCursor.crosshair.set()
            return
        }

        let location = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        updateCursor(for: location)
    }

    private func updateCursor(for point: CGPoint) {
        if isLongCaptureGuideMode {
            return
        }

        guard mode == .preview else {
            NSCursor.crosshair.set()
            return
        }

        if let previewSelectionRect, currentAnnotationTool != nil, previewSelectionRect.contains(point) {
            return
        }

        let interactionTarget = activeInteractionTarget != .none ? activeInteractionTarget : interactionTarget(for: point)
        hoverInteractionTarget = interactionTarget

        guard interactionTarget != .none else {
            NSCursor.crosshair.set()
            return
        }

        switch interactionTarget {
        case .move:
            if activeInteractionTarget == .move {
                NSCursor.closedHand.set()
            } else {
                NSCursor.openHand.set()
            }
        case .resizeLeft, .resizeRight:
            NSCursor.resizeLeftRight.set()
        case .resizeTop, .resizeBottom:
            NSCursor.resizeUpDown.set()
        case .resizeTopLeft, .resizeBottomRight:
            NSCursor._windowResizeNorthWestSouthEast.set()
        case .resizeTopRight, .resizeBottomLeft:
            NSCursor._windowResizeNorthEastSouthWest.set()
        case .none:
            NSCursor.crosshair.set()
        }
    }

    private func refreshHoveredWindowCandidate(at point: CGPoint) {
        guard mode == .selection, isDragging == false else {
            return
        }

        hoveredWindowCandidate = windowCandidateProvider?(point)
        needsDisplay = true
    }

    private func interactionTarget(for point: CGPoint) -> PreviewInteractionTarget {
        guard canEditPreviewSelection, let previewSelectionRect else {
            return .none
        }

        let cornerSize = Self.cornerHitSize
        let edgeThickness = Self.edgeHitThickness

        let topLeftCorner = CGRect(
            x: previewSelectionRect.minX - cornerSize / 2,
            y: previewSelectionRect.maxY - cornerSize / 2,
            width: cornerSize,
            height: cornerSize
        )
        let topRightCorner = CGRect(
            x: previewSelectionRect.maxX - cornerSize / 2,
            y: previewSelectionRect.maxY - cornerSize / 2,
            width: cornerSize,
            height: cornerSize
        )
        let bottomLeftCorner = CGRect(
            x: previewSelectionRect.minX - cornerSize / 2,
            y: previewSelectionRect.minY - cornerSize / 2,
            width: cornerSize,
            height: cornerSize
        )
        let bottomRightCorner = CGRect(
            x: previewSelectionRect.maxX - cornerSize / 2,
            y: previewSelectionRect.minY - cornerSize / 2,
            width: cornerSize,
            height: cornerSize
        )

        if topLeftCorner.contains(point) {
            return .resizeTopLeft
        }
        if topRightCorner.contains(point) {
            return .resizeTopRight
        }
        if bottomLeftCorner.contains(point) {
            return .resizeBottomLeft
        }
        if bottomRightCorner.contains(point) {
            return .resizeBottomRight
        }

        let leftEdge = CGRect(
            x: previewSelectionRect.minX - edgeThickness / 2,
            y: previewSelectionRect.minY + cornerSize / 2,
            width: edgeThickness,
            height: max(previewSelectionRect.height - cornerSize, 0)
        )
        let rightEdge = CGRect(
            x: previewSelectionRect.maxX - edgeThickness / 2,
            y: previewSelectionRect.minY + cornerSize / 2,
            width: edgeThickness,
            height: max(previewSelectionRect.height - cornerSize, 0)
        )
        let topEdge = CGRect(
            x: previewSelectionRect.minX + cornerSize / 2,
            y: previewSelectionRect.maxY - edgeThickness / 2,
            width: max(previewSelectionRect.width - cornerSize, 0),
            height: edgeThickness
        )
        let bottomEdge = CGRect(
            x: previewSelectionRect.minX + cornerSize / 2,
            y: previewSelectionRect.minY - edgeThickness / 2,
            width: max(previewSelectionRect.width - cornerSize, 0),
            height: edgeThickness
        )

        if leftEdge.contains(point) {
            return .resizeLeft
        }
        if rightEdge.contains(point) {
            return .resizeRight
        }
        if topEdge.contains(point) {
            return .resizeTop
        }
        if bottomEdge.contains(point) {
            return .resizeBottom
        }

        if previewSelectionRect.contains(point) {
            return .move
        }

        return .none
    }

    private func updateSizeLabel() {
        guard let previewSelectionRect else {
            return
        }

        sizeLabel.stringValue = "\(Int(previewSelectionRect.width)) x \(Int(previewSelectionRect.height))"
    }

    private func configureTopBar() {
        topBarContainerView.material = .hudWindow
        topBarContainerView.blendingMode = .withinWindow
        topBarContainerView.state = .active
        topBarContainerView.wantsLayer = true
        topBarContainerView.layer?.cornerRadius = 10

        sizeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        sizeLabel.textColor = .white
        cornerRadiusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        cornerRadiusLabel.textColor = .white

        cornerRadiusSlider.target = self
        cornerRadiusSlider.action = #selector(adjustCornerRadius)
        cornerRadiusSlider.controlSize = .small

        shadowToggle.target = self
        shadowToggle.action = #selector(toggleShadow)
        shadowToggle.contentTintColor = .white
        topBarContainerView.addSubview(sizeLabel)
        topBarContainerView.addSubview(cornerRadiusLabel)
        topBarContainerView.addSubview(cornerRadiusSlider)
        topBarContainerView.addSubview(shadowToggle)
        addSubview(topBarContainerView)
    }

    private func configureToolbar() {
        toolbarContainerView.material = .hudWindow
        toolbarContainerView.blendingMode = .withinWindow
        toolbarContainerView.state = .active
        toolbarContainerView.wantsLayer = true
        toolbarContainerView.layer?.cornerRadius = 12

        undoButton.target = self
        undoButton.action = #selector(requestUndo)
        longCaptureButton.target = self
        longCaptureButton.action = #selector(requestLongCapture)
        ocrButton.target = self
        ocrButton.action = #selector(requestOCR)
        aiButton.target = self
        aiButton.action = #selector(requestAI)
        pinButton.target = self
        pinButton.action = #selector(requestPin)
        copyButton.target = self
        copyButton.action = #selector(requestCopy)
        saveButton.target = self
        saveButton.action = #selector(requestSave)
        cancelButton.target = self
        cancelButton.action = #selector(requestCancel)

        let annotationButtons = AnnotationTool.allCases.map { tool -> NSButton in
            let button = NSButton(title: tool.title, target: self, action: #selector(selectAnnotationTool(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(tool.title)
            annotationToolButtons[tool] = button
            return button
        }

        (annotationButtons + [undoButton, longCaptureButton, ocrButton, aiButton, pinButton, copyButton, saveButton, cancelButton]).forEach { button in
            button.bezelStyle = .rounded
        }
        annotationButtons.forEach(toolbarContainerView.addSubview)
        toolbarContainerView.addSubview(undoButton)
        toolbarContainerView.addSubview(longCaptureButton)
        toolbarContainerView.addSubview(ocrButton)
        toolbarContainerView.addSubview(aiButton)
        toolbarContainerView.addSubview(pinButton)
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
        annotationCanvasView.frame = previewClipView.bounds

        sizeLabel.sizeToFit()
        cornerRadiusLabel.sizeToFit()
        shadowToggle.sizeToFit()

        let sliderWidth: CGFloat = 120
        let sliderHeight: CGFloat = 20
        cornerRadiusSlider.frame.size = CGSize(width: sliderWidth, height: sliderHeight)

        let topBarPaddingX: CGFloat = 12
        let topBarPaddingY: CGFloat = 6
        let topBarSpacing: CGFloat = 10
        let topBarContentHeight = max(
            sizeLabel.frame.height,
            cornerRadiusLabel.frame.height,
            cornerRadiusSlider.frame.height,
            shadowToggle.frame.height
        )
        let topBarWidth = topBarPaddingX * 2
            + sizeLabel.frame.width
            + topBarSpacing
            + cornerRadiusLabel.frame.width
            + topBarSpacing
            + cornerRadiusSlider.frame.width
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
        cornerRadiusLabel.frame.origin = CGPoint(
            x: currentTopBarX,
            y: (topBarHeight - cornerRadiusLabel.frame.height) / 2
        )
        currentTopBarX += cornerRadiusLabel.frame.width + topBarSpacing
        cornerRadiusSlider.frame.origin = CGPoint(
            x: currentTopBarX,
            y: (topBarHeight - cornerRadiusSlider.frame.height) / 2
        )
        currentTopBarX += cornerRadiusSlider.frame.width + topBarSpacing
        shadowToggle.frame.origin = CGPoint(
            x: currentTopBarX,
            y: (topBarHeight - shadowToggle.frame.height) / 2
        )

        let annotationButtons = AnnotationTool.allCases.compactMap { annotationToolButtons[$0] }
        annotationButtons.forEach { $0.sizeToFit() }
        undoButton.sizeToFit()
        longCaptureButton.sizeToFit()
        ocrButton.sizeToFit()
        aiButton.sizeToFit()
        pinButton.sizeToFit()
        copyButton.sizeToFit()
        saveButton.sizeToFit()
        cancelButton.sizeToFit()
        let toolbarButtons = annotationButtons + [undoButton, longCaptureButton, ocrButton, aiButton, pinButton, copyButton, saveButton, cancelButton]

        let toolbarPaddingX: CGFloat = 12
        let toolbarPaddingY: CGFloat = 6
        let toolbarSpacing: CGFloat = 12
        let toolbarContentHeight = max(
            toolbarButtons.map(\.frame.height).max() ?? 0,
            0
        )
        let toolbarWidth = toolbarPaddingX * 2
            + toolbarButtons.reduce(CGFloat(0)) { $0 + $1.frame.width }
            + (toolbarSpacing * CGFloat(max(toolbarButtons.count - 1, 0)))
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
        for button in toolbarButtons {
            button.frame.origin = CGPoint(
                x: currentToolbarX,
                y: (toolbarHeight - button.frame.height) / 2
            )
            currentToolbarX += button.frame.width + toolbarSpacing
        }
    }

    private func updatePreviewAppearance() {
        previewClipView.layer?.cornerRadius = previewStyle.cornerRadius
        previewContainerView.layer?.shadowColor = NSColor.black.cgColor
        previewContainerView.layer?.shadowOpacity = previewStyle.showsShadow ? 0.25 : 0
        previewContainerView.layer?.shadowRadius = previewStyle.showsShadow ? 12 : 0
        previewContainerView.layer?.shadowOffset = CGSize(width: 0, height: -4)
        needsDisplay = true
    }

    @objc
    private func adjustCornerRadius() {
        previewStyle.cornerRadius = CGFloat(cornerRadiusSlider.doubleValue)
        updatePreviewAppearance()
    }

    @objc
    private func toggleShadow() {
        previewStyle.showsShadow = shadowToggle.state == .on
        updatePreviewAppearance()
    }

    @objc
    private func requestUndo() {
        annotationCanvasView.undoLastAnnotation()
        window?.makeFirstResponder(annotationCanvasView)
    }

    @objc
    private func requestLongCapture() {
        annotationCanvasView.commitActiveTextIfNeeded()
        onLongCaptureRequested?(annotationCanvasView.annotations)
    }

    @objc
    private func requestCopy() {
        annotationCanvasView.commitActiveTextIfNeeded()
        onCopyRequested?(previewStyle, annotationCanvasView.annotations)
    }

    @objc
    private func requestSave() {
        annotationCanvasView.commitActiveTextIfNeeded()
        onSaveRequested?(previewStyle, annotationCanvasView.annotations)
    }

    @objc
    private func requestOCR() {
        annotationCanvasView.commitActiveTextIfNeeded()
        onOCRRequested?(previewStyle, annotationCanvasView.annotations)
    }

    @objc
    private func requestAI() {
        annotationCanvasView.commitActiveTextIfNeeded()
        presentAIMenu(relativeTo: aiButton)
    }

    private func presentAIMenu(relativeTo button: NSButton) {
        let menu = NSMenu()

        for mode in AIAnalysisMode.allCases {
            let item = NSMenuItem(title: mode.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            menu.addItem(item)
        }

        let menuOrigin = CGPoint(x: button.frame.minX, y: button.frame.maxY + 4)
        menu.popUp(positioning: nil, at: menuOrigin, in: toolbarContainerView)
    }

    @objc
    private func handleAIMenuSelection(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? AIAnalysisMode else {
            return
        }

        annotationCanvasView.commitActiveTextIfNeeded()
        onAIRequested?(mode, previewStyle, annotationCanvasView.annotations)
    }

    @objc
    private func requestPin() {
        annotationCanvasView.commitActiveTextIfNeeded()
        onPinRequested?(previewStyle, annotationCanvasView.annotations)
    }

    @objc
    private func requestCancel() {
        onCancel?()
    }

    @objc
    private func selectAnnotationTool(_ sender: NSButton) {
        guard let tool = annotationToolButtons.first(where: { $0.value === sender })?.key else {
            return
        }

        if currentAnnotationTool == tool {
            currentAnnotationTool = nil
        } else {
            currentAnnotationTool = tool
        }

        annotationCanvasView.currentTool = currentAnnotationTool
        updateAnnotationToolSelection()
        window?.makeFirstResponder(annotationCanvasView)
        updateCursorFromCurrentEvent()
    }

    private func updateAnnotationToolSelection() {
        for (tool, button) in annotationToolButtons {
            button.state = tool == currentAnnotationTool ? .on : .off
        }
    }

    private func updateAnnotationSourceImage() {
        guard
            let previewSelectionRect,
            let previewSourceScreenImage,
            let previewSourceScreenFrame,
            let window
        else {
            annotationCanvasView.sourceImage = nil
            return
        }

        let screenRect = window.convertToScreen(previewSelectionRect)
        let cropRect = CGRect(
            x: (screenRect.minX - previewSourceScreenFrame.minX) * (CGFloat(previewSourceScreenImage.width) / previewSourceScreenFrame.width),
            y: (previewSourceScreenFrame.maxY - screenRect.maxY) * (CGFloat(previewSourceScreenImage.height) / previewSourceScreenFrame.height),
            width: screenRect.width * (CGFloat(previewSourceScreenImage.width) / previewSourceScreenFrame.width),
            height: screenRect.height * (CGFloat(previewSourceScreenImage.height) / previewSourceScreenFrame.height)
        ).integral

        annotationCanvasView.sourceImage = previewSourceScreenImage.cropping(to: cropRect)
    }

    private func drawSelectionBackground(in dirtyRect: NSRect) {
        guard let selectionSourceScreenImage else {
            return
        }

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.draw(selectionSourceScreenImage, in: bounds)
    }

    private func cutoutPath(for rect: CGRect) -> NSBezierPath {
        if mode == .preview && previewStyle.cornerRadius > 0 {
            return NSBezierPath(
                roundedRect: rect,
                xRadius: previewStyle.cornerRadius,
                yRadius: previewStyle.cornerRadius
            )
        }

        return NSBezierPath(rect: rect)
    }

    private enum Mode {
        case selection
        case preview
    }

    private enum PreviewInteractionTarget {
        case none
        case move
        case resizeTop
        case resizeBottom
        case resizeLeft
        case resizeRight
        case resizeTopLeft
        case resizeTopRight
        case resizeBottomLeft
        case resizeBottomRight
    }
}

private extension NSCursor {
    static var _windowResizeNorthWestSouthEast: NSCursor {
        NSCursor(image: NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: nil) ?? NSImage(), hotSpot: NSPoint(x: 8, y: 8))
    }

    static var _windowResizeNorthEastSouthWest: NSCursor {
        NSCursor(image: NSImage(systemSymbolName: "arrow.up.right.and.arrow.down.left", accessibilityDescription: nil) ?? NSImage(), hotSpot: NSPoint(x: 8, y: 8))
    }
}
