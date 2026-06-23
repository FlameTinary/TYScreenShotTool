//
//  CaptureOverlayView.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/5.
//

import AppKit

/// 截图覆盖层视图
///
/// 处理截图选择、窗口高亮和预览交互的核心视图。
final class CaptureOverlayView: NSView {
    private static let maximumCornerRadius: Double = 100
    private static let toolbarTooltipOffset: CGFloat = 10
    private static let rectanglePanelSpacing: CGFloat = 8

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
    private let cornerRadiusLabel = NSTextField(labelWithString: "")
    private let cornerRadiusSlider = NSSlider(value: 0, minValue: 0, maxValue: maximumCornerRadius, target: nil, action: nil)
    private let shadowToggle = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let toolbarContainerView = NSVisualEffectView()
    private let toolbarTooltipView = NSVisualEffectView()
    private let toolbarTooltipLabel = NSTextField(labelWithString: "")
    private var annotationToolButtons: [AnnotationTool: NSButton] = [:]
    private let undoButton = ToolbarHoverButton(title: "", target: nil, action: nil)
    private let longCaptureButton = ToolbarHoverButton(title: "", target: nil, action: nil)
    private let ocrButton = ToolbarHoverButton(title: "OCR", target: nil, action: nil)
    private let aiButton = ToolbarHoverButton(title: "AI", target: nil, action: nil)
    private let pinButton = ToolbarHoverButton(title: "", target: nil, action: nil)
    private let copyButton = ToolbarHoverButton(title: "", target: nil, action: nil)
    private let saveButton = ToolbarHoverButton(title: "", target: nil, action: nil)
    private let cancelButton = ToolbarHoverButton(title: "", target: nil, action: nil)
    private let toolbarSymbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
    private let toolbarSelectedTintColor = NSColor.systemCyan
    private let toolbarButtonSize = CGSize(width: 30, height: 30)
    private let toolbarTextButtonMinWidth: CGFloat = 44
    private let toolbarButtonTintColor = NSColor.white
    private let toolbarButtonDisabledTintColor = NSColor.white.withAlphaComponent(0.35)
    private var currentAnnotationTool: AnnotationTool?

    /// 属性面板
    private let rectanglePanelView = RectanglePropertyPanelView()
    private let strokePanelView = StrokePropertyPanelView()
    private let arrowPanelView = ArrowPropertyPanelView()
    private let penPanelView = PenPropertyPanelView()
    private let mosaicPanelView = MosaicPropertyPanelView()
    /// 当前属性（新标注默认值 + 面板状态）
    private var currentRectangleProperties = RectangleProperties.default
    private var currentEllipseProperties = ShapeStrokeProperties.default
    private var currentLineProperties = ShapeStrokeProperties.default
    private var currentArrowProperties = ArrowProperties.default
    private var currentPenProperties = PenProperties.default
    private var currentMosaicProperties = MosaicProperties.default

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configurePreviewViews()
        configureTopBar()
        configureToolbar()
        configurePropertyPanel()
        applyAppearanceStyling()
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
        rectanglePanelView.isHidden = true
        strokePanelView.isHidden = true
        arrowPanelView.isHidden = true
        penPanelView.isHidden = true
        mosaicPanelView.isHidden = true
        annotationCanvasView.resetAnnotations()
        updateAnnotationToolSelection()

        previewContainerView.isHidden = false
        topBarContainerView.isHidden = false
        toolbarContainerView.isHidden = false
        toolbarTooltipView.isHidden = true
        aiButton.isEnabled = true

        updateAnnotationSourceImage()
        applyLocalizedStrings()
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
        rectanglePanelView.isHidden = true
        strokePanelView.isHidden = true
        arrowPanelView.isHidden = true
        penPanelView.isHidden = true
        mosaicPanelView.isHidden = true
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
        toolbarTooltipView.isHidden = true
        rectanglePanelView.isHidden = true
        strokePanelView.isHidden = true
        arrowPanelView.isHidden = true
        penPanelView.isHidden = true
        mosaicPanelView.isHidden = true
        aiButton.isEnabled = true
        needsDisplay = true
        NSCursor.crosshair.set()
    }

    func setAIButtonEnabled(_ isEnabled: Bool) {
        aiButton.isEnabled = isEnabled
        applyToolbarButtonAppearance(aiButton, isSelected: false)
    }

    func applyAppearanceStyling() {
        topBarContainerView.material = .popover
        toolbarContainerView.material = .popover
        sizeLabel.textColor = .labelColor
        cornerRadiusLabel.textColor = .labelColor
        shadowToggle.contentTintColor = .controlAccentColor
        annotationCanvasView.applyAppearanceStyling()
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
        topBarContainerView.material = .popover
        topBarContainerView.blendingMode = .withinWindow
        topBarContainerView.state = .active
        topBarContainerView.wantsLayer = true
        topBarContainerView.layer?.cornerRadius = 10

        sizeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        cornerRadiusLabel.font = .systemFont(ofSize: 13, weight: .medium)

        cornerRadiusSlider.target = self
        cornerRadiusSlider.action = #selector(adjustCornerRadius)
        cornerRadiusSlider.controlSize = .small

        shadowToggle.target = self
        shadowToggle.action = #selector(toggleShadow)
        applyLocalizedStrings()
        topBarContainerView.addSubview(sizeLabel)
        topBarContainerView.addSubview(cornerRadiusLabel)
        topBarContainerView.addSubview(cornerRadiusSlider)
        topBarContainerView.addSubview(shadowToggle)
        addSubview(topBarContainerView)
    }

    private func configurePropertyPanel() {
        rectanglePanelView.onPropertyChanged = { [weak self] properties in
            guard let self else { return }
            self.currentRectangleProperties = properties
            self.annotationCanvasView.currentRectangleProperties = properties
            self.annotationCanvasView.updateSelectedAnnotation(with: properties)
        }

        strokePanelView.onPropertyChanged = { [weak self] properties in
            guard let self else { return }
            switch self.currentAnnotationTool {
            case .ellipse:
                self.currentEllipseProperties = properties
                self.annotationCanvasView.currentEllipseProperties = properties
                self.annotationCanvasView.updateSelectedAnnotationProperties(.ellipse(properties))
            case .line:
                self.currentLineProperties = properties
                self.annotationCanvasView.currentLineProperties = properties
                self.annotationCanvasView.updateSelectedAnnotationProperties(.line(properties))
            default:
                break
            }
        }

        arrowPanelView.onPropertyChanged = { [weak self] properties in
            guard let self else { return }
            self.currentArrowProperties = properties
            self.annotationCanvasView.currentArrowProperties = properties
            self.annotationCanvasView.updateSelectedAnnotationProperties(.arrow(properties))
        }

        penPanelView.onPropertyChanged = { [weak self] properties in
            guard let self else { return }
            self.currentPenProperties = properties
            self.annotationCanvasView.currentPenProperties = properties
            self.annotationCanvasView.updateSelectedAnnotationProperties(.pen(properties))
        }

        mosaicPanelView.onPropertyChanged = { [weak self] properties in
            guard let self else { return }
            self.currentMosaicProperties = properties
            self.annotationCanvasView.currentMosaicProperties = properties
            self.annotationCanvasView.updateSelectedAnnotationProperties(.mosaic(properties))
        }

        annotationCanvasView.onAnnotationSelected = { [weak self] index, tool, properties in
            guard let self else { return }
            self.annotationCanvasView.selectedAnnotationIndex = index

            if let tool {
                self.currentAnnotationTool = tool
                self.annotationCanvasView.currentTool = tool
            }

            self.applySelection(properties)
            self.updateVisiblePropertyPanel()
            self.updateAnnotationToolSelection()
            self.needsLayout = true
        }

        rectanglePanelView.isHidden = true
        strokePanelView.isHidden = true
        arrowPanelView.isHidden = true
        penPanelView.isHidden = true
        mosaicPanelView.isHidden = true

        addSubview(rectanglePanelView)
        addSubview(strokePanelView)
        addSubview(arrowPanelView)
        addSubview(penPanelView)
        addSubview(mosaicPanelView)
    }

    private func configureToolbar() {
        toolbarContainerView.material = .popover
        toolbarContainerView.blendingMode = .withinWindow
        toolbarContainerView.state = .active
        toolbarContainerView.wantsLayer = true
        toolbarContainerView.layer?.cornerRadius = 12

        configureToolbarTooltip()

        let annotationButtons = AnnotationTool.allCases.map { tool -> NSButton in
            let button = makeToolbarButton(
                symbolName: tool.symbolName,
                accessibilityDescription: tool.title,
                toolTip: tool.title,
                action: #selector(selectAnnotationTool(_:))
            )
            button.identifier = NSUserInterfaceItemIdentifier(tool.rawIdentifier)
            annotationToolButtons[tool] = button
            return button
        }

        configureToolbarButton(
            undoButton,
            symbolName: "arrow.uturn.backward",
            accessibilityDescription: AppText.captureUndo,
            toolTip: AppText.captureUndo,
            action: #selector(requestUndo)
        )
        configureToolbarTextButton(
            longCaptureButton,
            title: AppText.captureLongCapture,
            accessibilityDescription: AppText.captureLongCapture,
            toolTip: AppText.captureLongCapture,
            action: #selector(requestLongCapture)
        )
        configureToolbarTextButton(
            ocrButton,
            title: "OCR",
            accessibilityDescription: "OCR",
            toolTip: "OCR",
            action: #selector(requestOCR)
        )
        configureToolbarTextButton(
            aiButton,
            title: "AI",
            accessibilityDescription: "AI",
            toolTip: "AI",
            action: #selector(requestAI)
        )
        configureToolbarButton(
            pinButton,
            symbolName: "pin",
            accessibilityDescription: AppText.capturePin,
            toolTip: AppText.capturePin,
            action: #selector(requestPin)
        )
        configureToolbarButton(
            copyButton,
            symbolName: "doc.on.doc",
            accessibilityDescription: AppText.captureCopy,
            toolTip: AppText.captureCopy,
            action: #selector(requestCopy)
        )
        configureToolbarButton(
            saveButton,
            symbolName: "square.and.arrow.down",
            accessibilityDescription: AppText.captureSave,
            toolTip: AppText.captureSave,
            action: #selector(requestSave)
        )
        configureToolbarButton(
            cancelButton,
            symbolName: "xmark",
            accessibilityDescription: AppText.captureCancel,
            toolTip: AppText.captureCancel,
            action: #selector(requestCancel)
        )
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
        addSubview(toolbarTooltipView)
    }

    private func applyLocalizedStrings() {
        cornerRadiusLabel.stringValue = AppText.captureCornerRadius
        shadowToggle.title = AppText.captureShadow

        for tool in AnnotationTool.allCases {
            annotationToolButtons[tool]?.toolTip = tool.title
            annotationToolButtons[tool]?.setAccessibilityLabel(tool.title)
        }

        undoButton.toolTip = AppText.captureUndo
        undoButton.setAccessibilityLabel(AppText.captureUndo)
        longCaptureButton.toolTip = AppText.captureLongCapture
        longCaptureButton.setAccessibilityLabel(AppText.captureLongCapture)
        ocrButton.toolTip = "OCR"
        ocrButton.setAccessibilityLabel("OCR")
        aiButton.toolTip = "AI"
        aiButton.setAccessibilityLabel("AI")
        pinButton.toolTip = AppText.capturePin
        pinButton.setAccessibilityLabel(AppText.capturePin)
        copyButton.toolTip = AppText.captureCopy
        copyButton.setAccessibilityLabel(AppText.captureCopy)
        saveButton.toolTip = AppText.captureSave
        saveButton.setAccessibilityLabel(AppText.captureSave)
        cancelButton.toolTip = AppText.captureCancel
        cancelButton.setAccessibilityLabel(AppText.captureCancel)

        updateToolbarHoverTooltips()
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
        let toolbarButtons = annotationButtons + [
            undoButton,
            longCaptureButton,
            ocrButton,
            aiButton,
            pinButton,
            copyButton,
            saveButton,
            cancelButton
        ]
        annotationButtons.forEach { button in
            button.frame.size = toolbarButtonSize
        }
        [undoButton, pinButton, copyButton, saveButton, cancelButton].forEach { button in
            button.frame.size = toolbarButtonSize
        }
        [longCaptureButton, ocrButton, aiButton].forEach(sizeToolbarTextButton(_:))

        let toolbarPaddingX: CGFloat = 12
        let toolbarPaddingY: CGFloat = 6
        let toolbarSpacing: CGFloat = 12
        let toolbarContentHeight = toolbarButtons.map(\.frame.height).max() ?? toolbarButtonSize.height
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

        if toolbarTooltipView.isHidden == false {
            repositionToolbarTooltip()
        }

        switch currentAnnotationTool {
        case .rectangle:
            layoutPropertyPanel(rectanglePanelView, tool: .rectangle, toolbarFrame: toolbarContainerView.frame, topBarFrame: topBarContainerView.frame)
        case .ellipse:
            layoutPropertyPanel(strokePanelView, tool: .ellipse, toolbarFrame: toolbarContainerView.frame, topBarFrame: topBarContainerView.frame)
        case .line:
            layoutPropertyPanel(strokePanelView, tool: .line, toolbarFrame: toolbarContainerView.frame, topBarFrame: topBarContainerView.frame)
        case .arrow:
            layoutPropertyPanel(arrowPanelView, tool: .arrow, toolbarFrame: toolbarContainerView.frame, topBarFrame: topBarContainerView.frame)
        case .pen:
            layoutPropertyPanel(penPanelView, tool: .pen, toolbarFrame: toolbarContainerView.frame, topBarFrame: topBarContainerView.frame)
        case .mosaic:
            layoutPropertyPanel(mosaicPanelView, tool: .mosaic, toolbarFrame: toolbarContainerView.frame, topBarFrame: topBarContainerView.frame)
        case .text, nil:
            break
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

        for mode in AIAnalysisMode.topLevelModes {
            let item = NSMenuItem(title: mode.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            menu.addItem(item)
        }

        let translationItem = NSMenuItem(
            title: AppText.aiTranslationMenu,
            action: nil,
            keyEquivalent: ""
        )
        let translationMenu = NSMenu()

        for language in AITranslationLanguage.allCases {
            let mode = AIAnalysisMode.translation(language)
            let item = NSMenuItem(title: mode.menuTitle, action: #selector(handleAIMenuSelection(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            translationMenu.addItem(item)
        }

        menu.setSubmenu(translationMenu, for: translationItem)
        menu.addItem(translationItem)

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

        currentAnnotationTool = tool
        annotationCanvasView.currentTool = tool
        annotationCanvasView.selectedAnnotationIndex = nil
        refreshCurrentToolPanelFromDefaults()
        updateVisiblePropertyPanel()
        updateAnnotationToolSelection()
        needsLayout = true
        window?.makeFirstResponder(annotationCanvasView)
        updateCursorFromCurrentEvent()
    }

    private func updateAnnotationToolSelection() {
        for tool in AnnotationTool.allCases {
            guard let button = annotationToolButtons[tool] else {
                continue
            }

            let isSelected = tool == currentAnnotationTool
            button.state = isSelected ? .on : .off
            applyToolbarButtonAppearance(button, isSelected: isSelected)

            if isSelected {
                animateToolbarSelectionFeedback(for: button)
            }
        }
    }

    private func makeToolbarButton(
        symbolName: String,
        accessibilityDescription: String,
        toolTip: String,
        action: Selector
    ) -> ToolbarHoverButton {
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityDescription
        )?.withSymbolConfiguration(toolbarSymbolConfiguration) ?? NSImage()

        let button = ToolbarHoverButton(image: image, target: self, action: action)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.focusRingType = .none
        button.toolTip = toolTip
        button.hoverToolTip = toolTip
        button.onHoverChanged = { [weak self, weak button] isHovered in
            guard let self, let button else {
                return
            }

            self.handleToolbarButtonHover(isHovered: isHovered, button: button)
        }
        button.setAccessibilityLabel(accessibilityDescription)
        applyToolbarButtonAppearance(button, isSelected: false)
        return button
    }

    private func configureToolbarTextButton(
        _ button: ToolbarHoverButton,
        title: String,
        accessibilityDescription: String,
        toolTip: String,
        action: Selector
    ) {
        button.image = nil
        button.title = title
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.alignment = .center
        button.imagePosition = .noImage
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.focusRingType = .none
        button.toolTip = toolTip
        button.hoverToolTip = toolTip
        button.onHoverChanged = { [weak self, weak button] isHovered in
            guard let self, let button else {
                return
            }

            self.handleToolbarButtonHover(isHovered: isHovered, button: button)
        }
        button.target = self
        button.action = action
        button.setAccessibilityLabel(accessibilityDescription)
        applyToolbarButtonAppearance(button, isSelected: false)
    }

    private func configureToolbarButton(
        _ button: ToolbarHoverButton,
        symbolName: String,
        accessibilityDescription: String,
        toolTip: String,
        action: Selector
    ) {
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityDescription
        )?.withSymbolConfiguration(toolbarSymbolConfiguration) ?? NSImage()

        button.title = ""
        button.image = image
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.focusRingType = .none
        button.toolTip = toolTip
        button.hoverToolTip = toolTip
        button.onHoverChanged = { [weak self, weak button] isHovered in
            guard let self, let button else {
                return
            }

            self.handleToolbarButtonHover(isHovered: isHovered, button: button)
        }
        button.target = self
        button.action = action
        button.setAccessibilityLabel(accessibilityDescription)
        applyToolbarButtonAppearance(button, isSelected: false)
    }

    private func sizeToolbarTextButton(_ button: NSButton) {
        button.sizeToFit()
        let width = max(toolbarTextButtonMinWidth, button.frame.width + 10)
        button.frame.size = CGSize(width: width, height: toolbarButtonSize.height)
    }

    private func animateToolbarSelectionFeedback(for button: NSButton) {
        button.wantsLayer = true

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.9
        scaleAnimation.toValue = 1.0
        scaleAnimation.duration = 0.18
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.7
        opacityAnimation.toValue = 1.0
        opacityAnimation.duration = 0.18
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        button.layer?.add(scaleAnimation, forKey: "toolbarSelectionScale")
        button.layer?.add(opacityAnimation, forKey: "toolbarSelectionOpacity")
    }

    private func applyToolbarButtonAppearance(_ button: NSButton, isSelected: Bool) {
        button.wantsLayer = false
        button.layer?.backgroundColor = nil
        if button.isEnabled == false {
            button.contentTintColor = toolbarButtonDisabledTintColor
        } else {
            button.contentTintColor = isSelected ? toolbarSelectedTintColor : toolbarButtonTintColor
        }
        button.needsDisplay = true
    }

    private func configureToolbarTooltip() {
        toolbarTooltipView.material = .popover
        toolbarTooltipView.blendingMode = .withinWindow
        toolbarTooltipView.state = .active
        toolbarTooltipView.wantsLayer = true
        toolbarTooltipView.layer?.cornerRadius = 8
        toolbarTooltipView.layer?.masksToBounds = true
        toolbarTooltipView.isHidden = true

        toolbarTooltipLabel.font = .systemFont(ofSize: 12, weight: .medium)
        toolbarTooltipLabel.textColor = .labelColor
        toolbarTooltipView.addSubview(toolbarTooltipLabel)
    }

    private func updateToolbarHoverTooltips() {
        for tool in AnnotationTool.allCases {
            (annotationToolButtons[tool] as? ToolbarHoverButton)?.hoverToolTip = tool.title
        }

        undoButton.hoverToolTip = AppText.captureUndo
        longCaptureButton.hoverToolTip = AppText.captureLongCapture
        ocrButton.hoverToolTip = "OCR"
        aiButton.hoverToolTip = "AI"
        pinButton.hoverToolTip = AppText.capturePin
        copyButton.hoverToolTip = AppText.captureCopy
        saveButton.hoverToolTip = AppText.captureSave
        cancelButton.hoverToolTip = AppText.captureCancel
    }

    private func handleToolbarButtonHover(isHovered: Bool, button: ToolbarHoverButton) {
        guard mode == .preview, toolbarContainerView.isHidden == false else {
            hideToolbarTooltip()
            return
        }

        if isHovered {
            showToolbarTooltip(for: button)
        } else {
            hideToolbarTooltip()
        }
    }

    private func showToolbarTooltip(for button: ToolbarHoverButton) {
        let tooltip = button.hoverToolTip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard tooltip.isEmpty == false else {
            hideToolbarTooltip()
            return
        }

        toolbarTooltipLabel.stringValue = tooltip
        toolbarTooltipLabel.sizeToFit()

        let paddingX: CGFloat = 10
        let paddingY: CGFloat = 6
        let width = toolbarTooltipLabel.frame.width + paddingX * 2
        let height = toolbarTooltipLabel.frame.height + paddingY * 2
        toolbarTooltipView.frame.size = CGSize(width: width, height: height)
        toolbarTooltipLabel.frame.origin = CGPoint(
            x: paddingX,
            y: (height - toolbarTooltipLabel.frame.height) / 2
        )

        positionToolbarTooltip(relativeTo: button)
        toolbarTooltipView.isHidden = false
    }

    private func repositionToolbarTooltip() {
        guard let hoveredButton = currentHoveredToolbarButton() else {
            hideToolbarTooltip()
            return
        }

        positionToolbarTooltip(relativeTo: hoveredButton)
    }

    private func positionToolbarTooltip(relativeTo button: ToolbarHoverButton) {
        let buttonFrameInOverlay = convert(button.bounds, from: button)
        let preferredX = buttonFrameInOverlay.midX - toolbarTooltipView.frame.width / 2
        let clampedX = min(
            max(preferredX, 16),
            bounds.width - toolbarTooltipView.frame.width - 16
        )

        var tooltipY = buttonFrameInOverlay.maxY + Self.toolbarTooltipOffset
        if tooltipY + toolbarTooltipView.frame.height > bounds.maxY - 16 {
            tooltipY = buttonFrameInOverlay.minY - toolbarTooltipView.frame.height - Self.toolbarTooltipOffset
        }

        toolbarTooltipView.frame.origin = CGPoint(x: clampedX, y: tooltipY)
    }

    private func hideToolbarTooltip() {
        toolbarTooltipView.isHidden = true
    }

    private func layoutPropertyPanel(
        _ panel: NSView,
        tool: AnnotationTool,
        toolbarFrame: CGRect,
        topBarFrame: CGRect
    ) {
        panel.layoutSubtreeIfNeeded()

        let fittingSize = panel.fittingSize
        let measuredWidth = fittingSize.width
        let measuredHeight = fittingSize.height

        let minSize: CGSize
        let maxWidth: CGFloat

        switch tool {
        case .rectangle:
            minSize = RectanglePropertyPanelView.minimumPanelSize
            maxWidth = RectanglePropertyPanelView.maximumPanelWidth
        case .ellipse, .line:
            minSize = StrokePropertyPanelView.minimumPanelSize
            maxWidth = StrokePropertyPanelView.maximumPanelWidth
        case .arrow:
            minSize = ArrowPropertyPanelView.minimumPanelSize
            maxWidth = ArrowPropertyPanelView.maximumPanelWidth
        case .pen:
            minSize = PenPropertyPanelView.minimumPanelSize
            maxWidth = PenPropertyPanelView.maximumPanelWidth
        case .mosaic:
            minSize = MosaicPropertyPanelView.minimumPanelSize
            maxWidth = MosaicPropertyPanelView.maximumPanelWidth
        case .text:
            return
        }

        let panelSize = CGSize(
            width: min(max(measuredWidth, minSize.width), maxWidth),
            height: max(measuredHeight, minSize.height)
        )

        let preferredX: CGFloat
        if let button = annotationToolButtons[tool] {
            preferredX = max(button.frame.minX, toolbarFrame.minX)
        } else {
            preferredX = toolbarFrame.minX
        }
        let clampedX = min(
            max(preferredX, toolbarFrame.minX),
            bounds.maxX - panelSize.width - 24
        )

        let preferredBelowY = toolbarFrame.minY - panelSize.height - Self.rectanglePanelSpacing
        let belowFits = preferredBelowY >= 24

        let fallbackAboveY = min(
            toolbarFrame.maxY + Self.rectanglePanelSpacing,
            bounds.maxY - panelSize.height - 24
        )
        let aboveOverlapsTopBar = fallbackAboveY < topBarFrame.maxY + Self.rectanglePanelSpacing
        let canPlaceAbove = aboveOverlapsTopBar == false

        let panelY: CGFloat
        if belowFits {
            panelY = preferredBelowY
        } else if canPlaceAbove {
            panelY = fallbackAboveY
        } else {
            panelY = max(24, min(preferredBelowY, bounds.maxY - panelSize.height - 24))
        }

        panel.frame = CGRect(
            x: clampedX,
            y: panelY,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    private func currentHoveredToolbarButton() -> ToolbarHoverButton? {
        let allButtons = annotationToolButtons.values.compactMap { $0 as? ToolbarHoverButton } + [
            undoButton,
            longCaptureButton,
            ocrButton,
            aiButton,
            pinButton,
            copyButton,
            saveButton,
            cancelButton
        ]

        return allButtons.first(where: \.isHovering)
    }

    // MARK: - Multi-Panel Helpers

    private func applySelection(_ properties: AnnotationEditableProperties?) {
        switch properties {
        case let .rectangle(value):
            currentRectangleProperties = value
            annotationCanvasView.currentRectangleProperties = value
            rectanglePanelView.updateDisplay(with: value)
        case let .ellipse(value):
            currentEllipseProperties = value
            annotationCanvasView.currentEllipseProperties = value
            strokePanelView.updateDisplay(with: value)
        case let .line(value):
            currentLineProperties = value
            annotationCanvasView.currentLineProperties = value
            strokePanelView.updateDisplay(with: value)
        case let .arrow(value):
            currentArrowProperties = value
            annotationCanvasView.currentArrowProperties = value
            arrowPanelView.updateDisplay(with: value)
        case let .pen(value):
            currentPenProperties = value
            annotationCanvasView.currentPenProperties = value
            penPanelView.updateDisplay(with: value)
        case let .mosaic(value):
            currentMosaicProperties = value
            annotationCanvasView.currentMosaicProperties = value
            mosaicPanelView.updateDisplay(with: value)
        case nil:
            refreshCurrentToolPanelFromDefaults()
        }
    }

    private func refreshCurrentToolPanelFromDefaults() {
        switch currentAnnotationTool {
        case .rectangle:
            annotationCanvasView.currentRectangleProperties = currentRectangleProperties
            rectanglePanelView.updateDisplay(with: currentRectangleProperties)
        case .ellipse:
            annotationCanvasView.currentEllipseProperties = currentEllipseProperties
            strokePanelView.updateDisplay(with: currentEllipseProperties)
        case .line:
            annotationCanvasView.currentLineProperties = currentLineProperties
            strokePanelView.updateDisplay(with: currentLineProperties)
        case .arrow:
            annotationCanvasView.currentArrowProperties = currentArrowProperties
            arrowPanelView.updateDisplay(with: currentArrowProperties)
        case .pen:
            annotationCanvasView.currentPenProperties = currentPenProperties
            penPanelView.updateDisplay(with: currentPenProperties)
        case .mosaic:
            annotationCanvasView.currentMosaicProperties = currentMosaicProperties
            mosaicPanelView.updateDisplay(with: currentMosaicProperties)
        case .text, nil:
            break
        }
    }

    private func updateVisiblePropertyPanel() {
        rectanglePanelView.isHidden = currentAnnotationTool != .rectangle
        strokePanelView.isHidden = currentAnnotationTool != .ellipse && currentAnnotationTool != .line
        arrowPanelView.isHidden = currentAnnotationTool != .arrow
        penPanelView.isHidden = currentAnnotationTool != .pen
        mosaicPanelView.isHidden = currentAnnotationTool != .mosaic
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

private final class ToolbarHoverButton: NSButton {
    var hoverToolTip: String = ""
    var onHoverChanged: ((Bool) -> Void)?

    private var trackingArea: NSTrackingArea?
    private(set) var isHovering = false

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea

        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        onHoverChanged?(false)
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
