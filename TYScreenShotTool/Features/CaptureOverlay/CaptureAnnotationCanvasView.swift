//
//  CaptureAnnotationCanvasView.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/7.
//

import AppKit
import CoreImage
import CoreText

/// 截图标注画布视图
///
/// 支持矩形、椭圆、箭头、画笔、马赛克和文字等标注工具。
final class CaptureAnnotationCanvasView: NSView, NSTextFieldDelegate {
    var annotationsDidChange: (([CaptureAnnotation]) -> Void)?
    var sourceImage: CGImage? {
        didSet {
            needsDisplay = true
        }
    }

    var currentTool: AnnotationTool? {
        didSet {
            if oldValue != currentTool {
                cancelActiveTextInput()
                temporaryAnnotation = nil
                hoverMosaicTarget = .none
                activeMosaicTarget = .none
                needsDisplay = true
                applyCursorForCurrentState()
            }
        }
    }

    private(set) var annotations: [CaptureAnnotation] = []

    private let ciContext = CIContext()
    private static let mosaicEdgeHitThickness: CGFloat = 8
    private static let mosaicCornerHitSize: CGFloat = 12
    private static let minimumMosaicSize: CGFloat = 12

    private var dragStartPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var temporaryAnnotation: CaptureAnnotation?
    private var activeTextField: NSTextField?
    private var activeTextOrigin: CGPoint?
    private var hoverMosaicTarget: MosaicInteractionTarget = .none
    private var activeMosaicTarget: MosaicInteractionTarget = .none
    private var activeMosaicIndex: Int?
    private var interactionStartMousePoint: CGPoint?
    private var interactionStartMosaicRect: CGRect?
    private var trackingArea: NSTrackingArea?

    /// 当前选中的标注索引（仅 rectangle 工具使用）
    var selectedAnnotationIndex: Int?
    /// 选中状态变更回调：索引, 属性值
    var onAnnotationSelected: ((Int?, RectangleProperties?) -> Void)?
    /// 新矩形使用的默认属性（由 CaptureOverlayView 同步）
    var currentRectangleProperties = RectangleProperties.default

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        currentTool != nil || activeTextField != nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard currentTool != nil || activeTextField != nil else {
            return nil
        }

        return super.hitTest(point)
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea

        super.updateTrackingAreas()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        for (index, annotation) in annotations.enumerated() {
            draw(annotation: annotation, at: index)
        }

        if let temporaryAnnotation {
            draw(annotation: temporaryAnnotation, at: nil)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)

        guard bounds.contains(point) else {
            super.mouseDown(with: event)
            return
        }

        switch currentTool {
        case .mosaic:
            if beginMosaicInteraction(at: point) {
                needsDisplay = true
                applyCursorForCurrentState()
                return
            }

            dragStartPoint = point
            currentPoint = point
            temporaryAnnotation = .mosaic(normalizedRect(from: point, to: point))
            needsDisplay = true
        case .rectangle:
            // 先检测是否点击了已画矩形（从后往前）
            if let hitIndex = hitTestRectangle(at: point) {
                selectedAnnotationIndex = hitIndex
                if case .rectangle(_, let props) = annotations[hitIndex] {
                    onAnnotationSelected?(hitIndex, props)
                }
                needsDisplay = true
                return
            }
            selectedAnnotationIndex = nil
            onAnnotationSelected?(nil, nil)
            fallthrough
        case .ellipse, .arrow:
            dragStartPoint = point
            currentPoint = point
            temporaryAnnotation = makeDragAnnotation(from: point, to: point)
            needsDisplay = true
        case .pen:
            dragStartPoint = point
            currentPoint = point
            temporaryAnnotation = .pen(points: [point])
            needsDisplay = true
        case .text:
            commitActiveTextIfNeeded()
            beginTextInput(at: point)
        case .none:
            super.mouseDown(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        switch currentTool {
        case .mosaic:
            if activeMosaicTarget != .none {
                updateActiveMosaic(with: point)
                needsDisplay = true
                applyCursorForCurrentState()
                return
            }

            guard let dragStartPoint else {
                return
            }

            currentPoint = point
            temporaryAnnotation = .mosaic(normalizedRect(from: dragStartPoint, to: point))
            needsDisplay = true
        case .rectangle, .ellipse, .arrow:
            guard let dragStartPoint else {
                return
            }

            currentPoint = point
            temporaryAnnotation = makeDragAnnotation(from: dragStartPoint, to: point)
            needsDisplay = true
        case .pen:
            guard case let .pen(points) = temporaryAnnotation else {
                return
            }

            currentPoint = point
            temporaryAnnotation = .pen(points: points + [point])
            needsDisplay = true
        case .text, .none:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        currentPoint = point

        switch currentTool {
        case .mosaic:
            if activeMosaicTarget != .none {
                finishMosaicInteraction(at: point)
                applyCursorForCurrentState()
                return
            }

            finalizeDragAnnotation()
        case .rectangle, .ellipse, .arrow:
            finalizeDragAnnotation()
        case .pen:
            finalizePenAnnotation()
        case .text, .none:
            break
        }
    }

    override func mouseMoved(with event: NSEvent) {
        updateMosaicHover(at: convert(event.locationInWindow, from: nil))
    }

    override func cursorUpdate(with event: NSEvent) {
        updateMosaicHover(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        hoverMosaicTarget = .none
        applyCursorForCurrentState()
    }

    func resetAnnotations() {
        cancelActiveTextInput()
        annotations.removeAll()
        dragStartPoint = nil
        currentPoint = nil
        temporaryAnnotation = nil
        selectedAnnotationIndex = nil
        annotationsDidChange?(annotations)
        needsDisplay = true
        applyCursorForCurrentState()
    }

    /// 更新选中矩形的样式属性（由面板回调触发）
    func updateSelectedAnnotation(with properties: RectangleProperties) {
        guard let idx = selectedAnnotationIndex,
              annotations.indices.contains(idx),
              case .rectangle(let rect, _) = annotations[idx] else { return }
        annotations[idx] = .rectangle(rect, properties)
        needsDisplay = true
    }

    func undoLastAnnotation() {
        commitActiveTextIfNeeded()

        guard annotations.isEmpty == false else {
            return
        }

        _ = annotations.removeLast()

        // 如果删除的标注恰好是被选中的，清空选中
        if let selectedIdx = selectedAnnotationIndex, !annotations.indices.contains(selectedIdx) {
            selectedAnnotationIndex = nil
            onAnnotationSelected?(nil, nil)
        }

        annotationsDidChange?(annotations)
        needsDisplay = true
        applyCursorForCurrentState()
    }

    var hasActiveTextInput: Bool {
        activeTextField != nil
    }

    func commitActiveTextIfNeeded() {
        guard let activeTextField, let activeTextOrigin else {
            return
        }

        let text = activeTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        activeTextField.removeFromSuperview()
        self.activeTextField = nil
        self.activeTextOrigin = nil

        guard text.isEmpty == false else {
            needsDisplay = true
            return
        }

        annotations.append(.text(value: text, origin: activeTextOrigin))
        annotationsDidChange?(annotations)
        needsDisplay = true
    }

    private func cancelActiveTextInput() {
        activeTextField?.removeFromSuperview()
        activeTextField = nil
        activeTextOrigin = nil
    }

    private func beginTextInput(at point: CGPoint) {
        let textField = NSTextField(frame: CGRect(x: point.x, y: point.y, width: 180, height: 30))
        textField.delegate = self
        textField.font = .systemFont(ofSize: CaptureAnnotation.fontSize, weight: .semibold)
        textField.textColor = NSColor(cgColor: CaptureAnnotation.strokeColor) ?? .systemRed
        textField.isBordered = false
        textField.focusRingType = .none
        textField.drawsBackground = true
        textField.placeholderString = AppText.captureTextInputPlaceholder
        textField.alignment = .left
        textField.target = self
        textField.action = #selector(commitTextInput)
        style(textField: textField)

        addSubview(textField)
        activeTextField = textField
        activeTextOrigin = point
        window?.makeFirstResponder(textField)
    }

    private func finalizeDragAnnotation() {
        defer {
            dragStartPoint = nil
            currentPoint = nil
            temporaryAnnotation = nil
            needsDisplay = true
        }

        guard let annotation = temporaryAnnotation else {
            return
        }

        switch annotation {
        case let .rectangle(rect, _):
            guard rect.standardized.width > 4, rect.standardized.height > 4 else {
                return
            }
        case let .ellipse(rect):
            guard rect.standardized.width > 4, rect.standardized.height > 4 else {
                return
            }
        case let .mosaic(rect):
            guard rect.standardized.width > 4, rect.standardized.height > 4 else {
                return
            }
        case let .arrow(start, end):
            guard hypot(end.x - start.x, end.y - start.y) > 8 else {
                return
            }
        case .pen, .text:
            return
        }

        annotations.append(annotation)
        annotationsDidChange?(annotations)
        applyCursorForCurrentState()
    }

    private func finalizePenAnnotation() {
        defer {
            dragStartPoint = nil
            currentPoint = nil
            temporaryAnnotation = nil
            needsDisplay = true
        }

        guard case let .pen(points) = temporaryAnnotation, points.count > 1 else {
            return
        }

        annotations.append(.pen(points: points))
        annotationsDidChange?(annotations)
        applyCursorForCurrentState()
    }

    private func makeDragAnnotation(from start: CGPoint, to end: CGPoint) -> CaptureAnnotation? {
        switch currentTool {
        case .rectangle:
            return .rectangle(normalizedRect(from: start, to: end), currentRectangleProperties)
        case .ellipse:
            return .ellipse(normalizedRect(from: start, to: end))
        case .arrow:
            return .arrow(start: start, end: end)
        case .mosaic:
            return .mosaic(normalizedRect(from: start, to: end))
        case .pen, .text, .none:
            return nil
        }
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func draw(annotation: CaptureAnnotation, at index: Int?) {
        switch annotation {
        case let .rectangle(rect, props):
            let standardizedRect = rect.standardized
            let path: NSBezierPath
            if props.cornerRadius > 0 {
                path = NSBezierPath(roundedRect: standardizedRect, xRadius: props.cornerRadius, yRadius: props.cornerRadius)
            } else {
                path = NSBezierPath(rect: standardizedRect)
            }

            let color = props.color.toNSColor().withAlphaComponent(props.opacity)

            if props.isFilled {
                color.setFill()
                path.fill()
                color.setStroke()
                path.lineWidth = props.lineWidth / 2
                path.stroke()
            } else {
                color.setStroke()
                path.lineWidth = props.lineWidth
                path.stroke()
            }

            // 选中高亮 — 青色虚线边框
            if let index, index == selectedAnnotationIndex {
                let highlightRect = standardizedRect.insetBy(dx: -4, dy: -4)
                let highlightPath: NSBezierPath
                if props.cornerRadius > 0 {
                    highlightPath = NSBezierPath(roundedRect: highlightRect, xRadius: props.cornerRadius + 4, yRadius: props.cornerRadius + 4)
                } else {
                    highlightPath = NSBezierPath(rect: highlightRect)
                }
                NSColor.systemCyan.setStroke()
                highlightPath.lineWidth = 2
                let dashes: [CGFloat] = [6, 4]
                highlightPath.setLineDash(dashes, count: 2, phase: 0)
                highlightPath.stroke()
            }
        case let .ellipse(rect):
            let path = NSBezierPath(ovalIn: rect.standardized)
            configureStroke()
            path.lineWidth = CaptureAnnotation.lineWidth
            path.stroke()
        case let .arrow(start, end):
            let path = arrowPath(from: start, to: end)
            configureStroke()
            path.stroke()
        case let .pen(points):
            guard let first = points.first else {
                return
            }

            let path = NSBezierPath()
            path.lineWidth = CaptureAnnotation.lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: first)

            for point in points.dropFirst() {
                path.line(to: point)
            }

            (NSColor(cgColor: CaptureAnnotation.strokeColor) ?? .systemRed).setStroke()
            path.stroke()
        case let .mosaic(rect):
            drawMosaic(in: rect.standardized)
        case let .text(value, origin):
            drawText(value, at: origin)
        }
    }

    private func configureStroke() {
        (NSColor(cgColor: CaptureAnnotation.strokeColor) ?? .systemRed).setStroke()
    }

    private func drawText(_ text: String, at origin: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: CaptureAnnotation.fontSize, weight: .semibold),
            .foregroundColor: NSColor(cgColor: CaptureAnnotation.strokeColor) ?? .systemRed
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(at: origin)
    }

    private func arrowPath(from start: CGPoint, to end: CGPoint) -> NSBezierPath {
        let path = NSBezierPath()
        path.lineWidth = CaptureAnnotation.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: start)
        path.line(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 14
        let arrowAngle: CGFloat = .pi / 7

        let leftPoint = CGPoint(
            x: end.x - cos(angle - arrowAngle) * arrowLength,
            y: end.y - sin(angle - arrowAngle) * arrowLength
        )
        let rightPoint = CGPoint(
            x: end.x - cos(angle + arrowAngle) * arrowLength,
            y: end.y - sin(angle + arrowAngle) * arrowLength
        )

        path.move(to: end)
        path.line(to: leftPoint)
        path.move(to: end)
        path.line(to: rightPoint)
        return path
    }

    private func drawMosaic(in rect: CGRect) {
        guard rect.width > 0, rect.height > 0 else {
            return
        }

        guard let sourceImage else {
            drawMosaicFallback(in: rect)
            return
        }

        guard bounds.width > 0, bounds.height > 0 else {
            drawMosaicFallback(in: rect)
            return
        }

        let imageScaleX = CGFloat(sourceImage.width) / bounds.width
        let imageScaleY = CGFloat(sourceImage.height) / bounds.height
        let imageRect = CGRect(
            x: rect.minX * imageScaleX,
            y: rect.minY * imageScaleY,
            width: rect.width * imageScaleX,
            height: rect.height * imageScaleY
        ).integral
        guard imageRect.width > 0, imageRect.height > 0 else {
            return
        }

        let fullImage = CIImage(cgImage: sourceImage)
        guard
            let filter = CIFilter(name: "CIGaussianBlur"),
            let outputContext = NSGraphicsContext.current?.cgContext
        else {
            drawMosaicFallback(in: rect)
            return
        }

        filter.setValue(fullImage, forKey: kCIInputImageKey)
        filter.setValue(CaptureAnnotation.mosaicBlurRadius, forKey: kCIInputRadiusKey)

        guard
            let blurredImage = filter.outputImage?.cropped(to: fullImage.extent),
            let blurredCGImage = ciContext.createCGImage(blurredImage, from: imageRect)
        else {
            drawMosaicFallback(in: rect)
            return
        }

        let path = NSBezierPath(
            roundedRect: rect,
            xRadius: CaptureAnnotation.mosaicCornerRadius,
            yRadius: CaptureAnnotation.mosaicCornerRadius
        )
        outputContext.saveGState()
        path.addClip()
        outputContext.draw(blurredCGImage, in: rect)
        outputContext.setFillColor(NSColor.white.withAlphaComponent(CaptureAnnotation.mosaicOverlayAlpha).cgColor)
        outputContext.fill(rect)
        outputContext.restoreGState()
    }

    private func drawMosaicFallback(in rect: CGRect) {
        let path = NSBezierPath(
            roundedRect: rect,
            xRadius: CaptureAnnotation.mosaicCornerRadius,
            yRadius: CaptureAnnotation.mosaicCornerRadius
        )
        NSColor.white.withAlphaComponent(0.16).setFill()
        path.fill()
    }

    private var hoverOrActiveMosaicTarget: MosaicInteractionTarget {
        activeMosaicTarget != .none ? activeMosaicTarget : hoverMosaicTarget
    }

    private func beginMosaicInteraction(at point: CGPoint) -> Bool {
        guard let result = mosaicInteraction(at: point) else {
            return false
        }

        activeMosaicIndex = result.index
        activeMosaicTarget = result.target
        interactionStartMousePoint = point
        interactionStartMosaicRect = result.rect
        hoverMosaicTarget = result.target
        return true
    }

    private func finishMosaicInteraction(at point: CGPoint) {
        updateActiveMosaic(with: point)
        activeMosaicIndex = nil
        activeMosaicTarget = .none
        interactionStartMousePoint = nil
        interactionStartMosaicRect = nil
        updateMosaicHover(at: point)
        annotationsDidChange?(annotations)
        applyCursorForCurrentState()
    }

    private func updateActiveMosaic(with point: CGPoint) {
        guard
            let activeMosaicIndex,
            let startPoint = interactionStartMousePoint,
            let startRect = interactionStartMosaicRect,
            annotations.indices.contains(activeMosaicIndex),
            case .mosaic = annotations[activeMosaicIndex]
        else {
            return
        }

        let updatedRect = updatedMosaicRect(
            from: startRect,
            startPoint: startPoint,
            currentPoint: point,
            target: activeMosaicTarget
        )
        annotations[activeMosaicIndex] = .mosaic(updatedRect)
    }

    private func updateMosaicHover(at point: CGPoint) {
        let previous = hoverMosaicTarget
        hoverMosaicTarget = mosaicInteraction(at: point)?.target ?? .none
        if previous != hoverMosaicTarget || activeMosaicTarget != .none {
            applyCursorForCurrentState()
        }
    }

    private func applyCursorForCurrentState() {
        cursor(for: hoverOrActiveMosaicTarget).set()
    }

    private func cursor(for target: MosaicInteractionTarget) -> NSCursor {
        guard currentTool == .mosaic else {
            return .crosshair
        }

        switch target {
        case .move:
            return activeMosaicTarget == .move ? .closedHand : .openHand
        case .resizeLeft, .resizeRight:
            return .resizeLeftRight
        case .resizeTop, .resizeBottom:
            return .resizeUpDown
        case .resizeTopLeft, .resizeBottomRight:
            return ._windowResizeNorthWestSouthEast
        case .resizeTopRight, .resizeBottomLeft:
            return ._windowResizeNorthEastSouthWest
        case .none:
            return .crosshair
        }
    }

    private func updatedMosaicRect(
        from rect: CGRect,
        startPoint: CGPoint,
        currentPoint: CGPoint,
        target: MosaicInteractionTarget
    ) -> CGRect {
        let deltaX = currentPoint.x - startPoint.x
        let deltaY = currentPoint.y - startPoint.y

        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        switch target {
        case .move:
            return constrainedRect(rect.offsetBy(dx: deltaX, dy: deltaY))
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

        return constrainedResizeRect(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }

    private func constrainedRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: min(max(rect.minX, bounds.minX), bounds.maxX - rect.width),
            y: min(max(rect.minY, bounds.minY), bounds.maxY - rect.height),
            width: rect.width,
            height: rect.height
        )
    }

    private func constrainedResizeRect(minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) -> CGRect {
        var adjustedMinX = max(minX, bounds.minX)
        var adjustedMaxX = min(maxX, bounds.maxX)
        var adjustedMinY = max(minY, bounds.minY)
        var adjustedMaxY = min(maxY, bounds.maxY)

        if adjustedMaxX - adjustedMinX < Self.minimumMosaicSize {
            adjustedMaxX = min(bounds.maxX, adjustedMinX + Self.minimumMosaicSize)
            adjustedMinX = max(bounds.minX, adjustedMaxX - Self.minimumMosaicSize)
        }

        if adjustedMaxY - adjustedMinY < Self.minimumMosaicSize {
            adjustedMaxY = min(bounds.maxY, adjustedMinY + Self.minimumMosaicSize)
            adjustedMinY = max(bounds.minY, adjustedMaxY - Self.minimumMosaicSize)
        }

        return CGRect(
            x: adjustedMinX,
            y: adjustedMinY,
            width: adjustedMaxX - adjustedMinX,
            height: adjustedMaxY - adjustedMinY
        )
    }

    private func mosaicInteraction(at point: CGPoint) -> (index: Int, rect: CGRect, target: MosaicInteractionTarget)? {
        guard currentTool == .mosaic else {
            return nil
        }

        for index in annotations.indices.reversed() {
            guard case let .mosaic(rect) = annotations[index] else {
                continue
            }

            let target = mosaicInteractionTarget(for: point, in: rect.standardized)
            if target != .none {
                return (index, rect.standardized, target)
            }
        }

        return nil
    }

    /// 检测点击点是否落在某个已画矩形上
    /// 从后往前遍历，返回最顶层矩形的索引
    private func hitTestRectangle(at point: CGPoint) -> Int? {
        for index in annotations.indices.reversed() {
            guard case .rectangle(let rect, _) = annotations[index] else {
                continue
            }
            if rect.standardized.contains(point) {
                return index
            }
        }
        return nil
    }

    private func mosaicInteractionTarget(for point: CGPoint, in rect: CGRect) -> MosaicInteractionTarget {
        let cornerSize = Self.mosaicCornerHitSize
        let edgeThickness = Self.mosaicEdgeHitThickness

        let topLeftCorner = CGRect(x: rect.minX - cornerSize / 2, y: rect.maxY - cornerSize / 2, width: cornerSize, height: cornerSize)
        let topRightCorner = CGRect(x: rect.maxX - cornerSize / 2, y: rect.maxY - cornerSize / 2, width: cornerSize, height: cornerSize)
        let bottomLeftCorner = CGRect(x: rect.minX - cornerSize / 2, y: rect.minY - cornerSize / 2, width: cornerSize, height: cornerSize)
        let bottomRightCorner = CGRect(x: rect.maxX - cornerSize / 2, y: rect.minY - cornerSize / 2, width: cornerSize, height: cornerSize)

        if topLeftCorner.contains(point) { return .resizeTopLeft }
        if topRightCorner.contains(point) { return .resizeTopRight }
        if bottomLeftCorner.contains(point) { return .resizeBottomLeft }
        if bottomRightCorner.contains(point) { return .resizeBottomRight }

        let leftEdge = CGRect(x: rect.minX - edgeThickness / 2, y: rect.minY + cornerSize / 2, width: edgeThickness, height: max(rect.height - cornerSize, 0))
        let rightEdge = CGRect(x: rect.maxX - edgeThickness / 2, y: rect.minY + cornerSize / 2, width: edgeThickness, height: max(rect.height - cornerSize, 0))
        let topEdge = CGRect(x: rect.minX + cornerSize / 2, y: rect.maxY - edgeThickness / 2, width: max(rect.width - cornerSize, 0), height: edgeThickness)
        let bottomEdge = CGRect(x: rect.minX + cornerSize / 2, y: rect.minY - edgeThickness / 2, width: max(rect.width - cornerSize, 0), height: edgeThickness)

        if leftEdge.contains(point) { return .resizeLeft }
        if rightEdge.contains(point) { return .resizeRight }
        if topEdge.contains(point) { return .resizeTop }
        if bottomEdge.contains(point) { return .resizeBottom }
        if rect.contains(point) { return .move }
        return .none
    }

    @objc
    private func commitTextInput() {
        commitActiveTextIfNeeded()
    }

    func applyAppearanceStyling() {
        if let activeTextField {
            style(textField: activeTextField)
        }
    }

    private func style(textField: NSTextField) {
        textField.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.92)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        commitActiveTextIfNeeded()
    }

    private enum MosaicInteractionTarget: Equatable {
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
        NSCursor(
            image: NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: nil) ?? NSImage(),
            hotSpot: NSPoint(x: 8, y: 8)
        )
    }

    static var _windowResizeNorthEastSouthWest: NSCursor {
        NSCursor(
            image: NSImage(systemSymbolName: "arrow.up.right.and.arrow.down.left", accessibilityDescription: nil) ?? NSImage(),
            hotSpot: NSPoint(x: 8, y: 8)
        )
    }
}
