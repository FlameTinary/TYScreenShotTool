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
                hoverRectTarget = .none
                activeRectTarget = .none
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
    private var hoverMosaicTarget: AnnotationResizeTarget = .none
    private var activeMosaicTarget: AnnotationResizeTarget = .none
    private var activeMosaicIndex: Int?
    private var interactionStartMousePoint: CGPoint?
    private var interactionStartMosaicRect: CGRect?
    private var trackingArea: NSTrackingArea?

    private var activeRectIndex: Int?
    private var activeRectTarget: AnnotationResizeTarget = .none
    private var interactionStartRect: CGRect?
    private var hoverRectTarget: AnnotationResizeTarget = .none

    /// 拖拽已选中标注：鼠标按下位置（overlay 坐标系）
    private var isDraggingAnnotation = false
    private var annotationDragStartPoint: CGPoint?

    /// 当前选中的标注索引（仅 rectangle 工具使用）
    var selectedAnnotationIndex: Int?
    /// 选中状态变更回调：索引, 工具, 属性值
    var onAnnotationSelected: ((Int?, AnnotationTool?, AnnotationEditableProperties?) -> Void)?
    /// 新矩形使用的默认属性（由 CaptureOverlayView 同步）
    var currentRectangleProperties = RectangleProperties.default
    var currentEllipseProperties = ShapeStrokeProperties.default
    var currentLineProperties = ShapeStrokeProperties.default
    var currentArrowProperties = ArrowProperties.default
    var currentPenProperties = PenProperties.default
    var currentMosaicProperties = MosaicProperties.default
    var currentTextProperties = TextProperties.default {
        didSet {
            guard let activeTextField else { return }
            applyTextProperties(currentTextProperties, to: activeTextField)
        }
    }

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

        // 马赛克工具：保持原有 resize / 移动交互优先
        if currentTool == .mosaic, beginMosaicInteraction(at: point) {
            needsDisplay = true
            applyCursorForCurrentState()
            return
        }

        // 矩形工具：选中矩形后支持 resize / 移动交互
        if currentTool == .rectangle, let result = rectangleInteraction(at: point) {
            activeRectIndex = result.index
            activeRectTarget = result.target
            interactionStartMousePoint = point
            interactionStartRect = result.rect
            hoverRectTarget = result.target
            needsDisplay = true
            applyCursorForCurrentState()
            return
        }

        // 通用命中检测：选择已有标注，或拖拽已选中标注
        if let hitResult = hitTestEditableAnnotation(at: point) {
            if hitResult.index == selectedAnnotationIndex {
                // 再次点击已选中标注 → 进入拖拽移动
                isDraggingAnnotation = true
                annotationDragStartPoint = point
            } else {
                // 点击其他标注 → 选中
                selectedAnnotationIndex = hitResult.index
                onAnnotationSelected?(hitResult.index, hitResult.tool, hitResult.properties)
            }
            needsDisplay = true
            return
        }

        // 空白区域：取消选中
        selectedAnnotationIndex = nil
        onAnnotationSelected?(nil, currentTool, nil)

        // 按当前工具创建新标注
        switch currentTool {
        case .mosaic:
            dragStartPoint = point
            currentPoint = point
            temporaryAnnotation = .mosaic(normalizedRect(from: point, to: point), currentMosaicProperties)
            needsDisplay = true
        case .rectangle, .ellipse, .line, .arrow:
            dragStartPoint = point
            currentPoint = point
            temporaryAnnotation = makeDragAnnotation(from: point, to: point)
            needsDisplay = true
        case .pen:
            dragStartPoint = point
            currentPoint = point
            temporaryAnnotation = .pen(points: [point], currentPenProperties)
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

        // 矩形工具：选中矩形后支持 resize / 移动交互
        if currentTool == .rectangle, activeRectTarget != .none {
            updateSelectedRectangle(with: point)
            needsDisplay = true
            applyCursorForCurrentState()
            return
        }

        // 拖拽已选中标注（非马赛克移动模式，马赛克走现有 resize/move 交互）
        if isDraggingAnnotation, let startPoint = annotationDragStartPoint,
           let idx = selectedAnnotationIndex {
            let deltaX = point.x - startPoint.x
            let deltaY = point.y - startPoint.y
            moveAnnotation(at: idx, by: CGPoint(x: deltaX, y: deltaY))
            annotationDragStartPoint = point
            needsDisplay = true
            return
        }

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
            temporaryAnnotation = .mosaic(normalizedRect(from: dragStartPoint, to: point), currentMosaicProperties)
            needsDisplay = true
        case .rectangle, .ellipse, .line, .arrow:
            guard let dragStartPoint else {
                return
            }

            currentPoint = point
            temporaryAnnotation = makeDragAnnotation(from: dragStartPoint, to: point)
            needsDisplay = true
        case .pen:
            guard case let .pen(points, properties) = temporaryAnnotation else {
                return
            }

            currentPoint = point
            temporaryAnnotation = .pen(points: points + [point], properties)
            needsDisplay = true
        case .text, .none:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        currentPoint = point

        if isDraggingAnnotation {
            isDraggingAnnotation = false
            annotationDragStartPoint = nil
            annotationsDidChange?(annotations)
            applyCursorForCurrentState()
            return
        }

        // 矩形工具：选中矩形后支持 resize / 移动交互
        if currentTool == .rectangle, activeRectTarget != .none {
            updateSelectedRectangle(with: point)
            activeRectIndex = nil
            activeRectTarget = .none
            interactionStartMousePoint = nil
            interactionStartRect = nil
            updateRectHover(at: point)
            annotationsDidChange?(annotations)
            applyCursorForCurrentState()
            return
        }

        switch currentTool {
        case .mosaic:
            if activeMosaicTarget != .none {
                finishMosaicInteraction(at: point)
                applyCursorForCurrentState()
                return
            }

            finalizeDragAnnotation()
        case .rectangle, .ellipse, .line, .arrow:
            finalizeDragAnnotation()
        case .pen:
            finalizePenAnnotation()
        case .text, .none:
            break
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateMosaicHover(at: point)
        updateRectHover(at: point)
    }

    override func cursorUpdate(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateMosaicHover(at: point)
        updateRectHover(at: point)
    }

    override func mouseExited(with event: NSEvent) {
        hoverMosaicTarget = .none
        hoverRectTarget = .none
        applyCursorForCurrentState()
    }

    func resetAnnotations() {
        cancelActiveTextInput()
        annotations.removeAll()
        dragStartPoint = nil
        currentPoint = nil
        temporaryAnnotation = nil
        selectedAnnotationIndex = nil
        activeRectIndex = nil
        activeRectTarget = .none
        hoverRectTarget = .none
        interactionStartRect = nil
        annotationsDidChange?(annotations)
        needsDisplay = true
        applyCursorForCurrentState()
    }

    func updateSelectedAnnotationProperties(_ properties: AnnotationEditableProperties) {
        guard let idx = selectedAnnotationIndex, annotations.indices.contains(idx) else { return }

        switch (annotations[idx], properties) {
        case let (.rectangle(rect, _), .rectangle(value)):
            annotations[idx] = .rectangle(rect, value)
        case let (.ellipse(rect, _), .ellipse(value)):
            annotations[idx] = .ellipse(rect, value)
        case let (.line(start, end, _), .line(value)):
            annotations[idx] = .line(start: start, end: end, value)
        case let (.arrow(start, end, _), .arrow(value)):
            annotations[idx] = .arrow(start: start, end: end, value)
        case let (.pen(points, _), .pen(value)):
            annotations[idx] = .pen(points: points, value)
        case let (.mosaic(rect, _), .mosaic(value)):
            annotations[idx] = .mosaic(rect, value)
        case let (.text(value, origin, _), .text(properties)):
            annotations[idx] = .text(value: value, origin: origin, properties: properties)
        default:
            return
        }

        annotationsDidChange?(annotations)
        needsDisplay = true
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
            onAnnotationSelected?(nil, currentTool, nil)
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

        annotations.append(.text(value: text, origin: activeTextOrigin, properties: currentTextProperties))
        annotationsDidChange?(annotations)
        needsDisplay = true
    }

    private func cancelActiveTextInput() {
        activeTextField?.removeFromSuperview()
        activeTextField = nil
        activeTextOrigin = nil
    }

    private func beginTextInput(at point: CGPoint) {
        let textField = NSTextField(
            frame: CGRect(
                x: point.x,
                y: point.y,
                width: max(180, currentTextProperties.fontSize * 6),
                height: currentTextProperties.editorHeight
            )
        )
        textField.delegate = self
        textField.isBordered = false
        textField.focusRingType = .none
        textField.drawsBackground = true
        textField.placeholderString = AppText.captureTextInputPlaceholder
        textField.alignment = .left
        textField.target = self
        textField.action = #selector(commitTextInput)
        style(textField: textField)
        applyTextProperties(currentTextProperties, to: textField)

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
        case let .ellipse(rect, _):
            guard rect.standardized.width > 4, rect.standardized.height > 4 else {
                return
            }
        case let .mosaic(rect, _):
            guard rect.standardized.width > 4, rect.standardized.height > 4 else {
                return
            }
        case let .arrow(start, end, _):
            guard hypot(end.x - start.x, end.y - start.y) > 8 else {
                return
            }
        case let .line(start, end, _):
            guard hypot(end.x - start.x, end.y - start.y) > 4 else {
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

        guard case let .pen(points, properties) = temporaryAnnotation, points.count > 1 else {
            return
        }

        annotations.append(.pen(points: points, properties))
        annotationsDidChange?(annotations)
        applyCursorForCurrentState()
    }

    private func makeDragAnnotation(from start: CGPoint, to end: CGPoint) -> CaptureAnnotation? {
        switch currentTool {
        case .rectangle:
            return .rectangle(normalizedRect(from: start, to: end), currentRectangleProperties)
        case .ellipse:
            return .ellipse(normalizedRect(from: start, to: end), currentEllipseProperties)
        case .line:
            return .line(start: start, end: end, currentLineProperties)
        case .arrow:
            return .arrow(start: start, end: end, currentArrowProperties)
        case .mosaic:
            return .mosaic(normalizedRect(from: start, to: end), currentMosaicProperties)
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

            if let index, index == selectedAnnotationIndex {
                let controlPoints = resizeControlPoints(for: standardizedRect)
                for point in controlPoints {
                    let handlePath = NSBezierPath(ovalIn: CGRect(
                        x: point.x - 6,
                        y: point.y - 6,
                        width: 12,
                        height: 12
                    ))
                    NSColor.white.setFill()
                    handlePath.fill()
                    NSColor.red.setStroke()
                    handlePath.lineWidth = 2
                    handlePath.stroke()
                }
            }
        case let .ellipse(rect, props):
            let path = NSBezierPath(ovalIn: rect.standardized)
            props.color.toNSColor().withAlphaComponent(props.opacity).setStroke()
            path.lineWidth = props.lineWidth
            path.stroke()

            // 选中高亮 — 青色虚线边框
            if let index, index == selectedAnnotationIndex {
                let highlightInset = -(props.lineWidth / 2 + 4)
                let highlightRect = rect.standardized.insetBy(dx: highlightInset, dy: highlightInset)
                let highlightPath = NSBezierPath(ovalIn: highlightRect)
                NSColor.systemCyan.setStroke()
                highlightPath.lineWidth = 2
                let dashes: [CGFloat] = [6, 4]
                highlightPath.setLineDash(dashes, count: 2, phase: 0)
                highlightPath.stroke()
            }
        case let .line(start, end, props):
            // 选中高亮 — 加宽虚线路径，先画在底层
            if let index, index == selectedAnnotationIndex {
                let highlightPath = NSBezierPath()
                highlightPath.move(to: start)
                highlightPath.line(to: end)
                highlightPath.lineWidth = props.lineWidth + 4
                highlightPath.lineCapStyle = .round
                highlightPath.lineJoinStyle = .round
                NSColor.systemCyan.setStroke()
                let dashes: [CGFloat] = [6, 4]
                highlightPath.setLineDash(dashes, count: 2, phase: 0)
                highlightPath.stroke()
            }

            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            path.lineWidth = props.lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            props.color.toNSColor().withAlphaComponent(props.opacity).setStroke()
            path.stroke()
        case let .arrow(start, end, props):
            // 选中高亮 — 加宽虚线路径，先画在底层
            if let index, index == selectedAnnotationIndex {
                let highlightPath = arrowPath(from: start, to: end, isCurved: props.isCurved)
                highlightPath.lineWidth = props.lineWidth + 4
                NSColor.systemCyan.setStroke()
                let dashes: [CGFloat] = [6, 4]
                highlightPath.setLineDash(dashes, count: 2, phase: 0)
                highlightPath.stroke()
            }

            let path = arrowPath(from: start, to: end, isCurved: props.isCurved)
            path.lineWidth = props.lineWidth
            props.color.toNSColor().withAlphaComponent(props.opacity).setStroke()
            path.stroke()
        case let .pen(points, props):
            guard let first = points.first else { return }

            // 选中高亮 — 加宽虚线路径，先画在底层
            if let index, index == selectedAnnotationIndex {
                let highlightPath = NSBezierPath()
                highlightPath.lineWidth = props.lineWidth + 4
                highlightPath.lineCapStyle = .round
                highlightPath.lineJoinStyle = .round
                highlightPath.move(to: first)
                for point in points.dropFirst() {
                    highlightPath.line(to: point)
                }
                NSColor.systemCyan.setStroke()
                let dashes: [CGFloat] = [6, 4]
                highlightPath.setLineDash(dashes, count: 2, phase: 0)
                highlightPath.stroke()
            }

            let path = NSBezierPath()
            path.lineWidth = props.lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: first)

            for point in points.dropFirst() {
                path.line(to: point)
            }

            if props.mode == .singleColor {
                props.color.toNSColor().withAlphaComponent(props.opacity).setStroke()
                path.stroke()
            } else {
                drawEffectStroke(path: path, mode: props.mode)
            }
        case let .mosaic(rect, props):
            drawMosaic(in: rect.standardized, properties: props)

            // 选中高亮 — 青色虚线边框
            if let index, index == selectedAnnotationIndex {
                let highlightRect = rect.standardized.insetBy(dx: -4, dy: -4)
                let highlightPath = NSBezierPath(
                    roundedRect: highlightRect,
                    xRadius: CaptureAnnotation.mosaicCornerRadius + 4,
                    yRadius: CaptureAnnotation.mosaicCornerRadius + 4
                )
                NSColor.systemCyan.setStroke()
                highlightPath.lineWidth = 2
                let dashes: [CGFloat] = [6, 4]
                highlightPath.setLineDash(dashes, count: 2, phase: 0)
                highlightPath.stroke()
            }
        case let .text(value, origin, properties):
            drawText(value, at: origin, properties: properties)
        }
    }

    private func drawText(_ text: String, at origin: CGPoint, properties: TextProperties) {
        let attributedString = NSAttributedString(string: text, attributes: properties.textAttributes)
        attributedString.draw(at: origin)
    }

    private func arrowPath(from start: CGPoint, to end: CGPoint, isCurved: Bool) -> NSBezierPath {
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let arrowEnd: CGPoint
        let arrowAngle: CGFloat

        if isCurved {
            let control = CGPoint(
                x: (start.x + end.x) / 2,
                y: max(start.y, end.y) + min(abs(end.x - start.x), 60)
            )
            path.move(to: start)
            path.curve(to: end, controlPoint1: control, controlPoint2: control)
            arrowEnd = end
            // Approximate tangent direction at endpoint
            let tangentDx = end.x - control.x
            let tangentDy = end.y - control.y
            arrowAngle = atan2(tangentDy, tangentDx)
        } else {
            path.move(to: start)
            path.line(to: end)
            arrowEnd = end
            arrowAngle = atan2(end.y - start.y, end.x - start.x)
        }

        let arrowLength: CGFloat = 14
        let arrowSpread: CGFloat = .pi / 7

        let leftPoint = CGPoint(
            x: arrowEnd.x - cos(arrowAngle - arrowSpread) * arrowLength,
            y: arrowEnd.y - sin(arrowAngle - arrowSpread) * arrowLength
        )
        let rightPoint = CGPoint(
            x: arrowEnd.x - cos(arrowAngle + arrowSpread) * arrowLength,
            y: arrowEnd.y - sin(arrowAngle + arrowSpread) * arrowLength
        )

        path.move(to: arrowEnd)
        path.line(to: leftPoint)
        path.move(to: arrowEnd)
        path.line(to: rightPoint)
        return path
    }

    private func resizeControlPoints(for rect: CGRect) -> [CGPoint] {
        return [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.midY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.midY)
        ]
    }

    private func drawMosaic(in rect: CGRect, properties: MosaicProperties) {
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
        guard let outputContext = NSGraphicsContext.current?.cgContext else {
            drawMosaicFallback(in: rect)
            return
        }

        let cutoutImage: CGImage?

        switch properties.style {
        case .mosaic:
            guard let filter = CIFilter(name: "CIPixellate") else {
                drawMosaicFallback(in: rect)
                return
            }
            filter.setValue(fullImage, forKey: kCIInputImageKey)
            filter.setValue(max(10, properties.size * 8), forKey: kCIInputScaleKey)
            cutoutImage = filter.outputImage
                .flatMap { $0.cropped(to: fullImage.extent) }
                .flatMap { ciContext.createCGImage($0, from: imageRect) }
        case .glass:
            guard let filter = CIFilter(name: "CIGaussianBlur") else {
                drawMosaicFallback(in: rect)
                return
            }
            filter.setValue(fullImage, forKey: kCIInputImageKey)
            filter.setValue(max(8, properties.size * 6), forKey: kCIInputRadiusKey)
            cutoutImage = filter.outputImage
                .flatMap { $0.cropped(to: fullImage.extent) }
                .flatMap { ciContext.createCGImage($0, from: imageRect) }
        }

        guard let cutoutImage else {
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
        outputContext.draw(cutoutImage, in: rect)
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

    private func drawEffectStroke(path: NSBezierPath, mode: PenMode) {
        guard let sourceImage, let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        let clipBounds = path.bounds.insetBy(dx: -20, dy: -20)
        guard clipBounds.width > 0, clipBounds.height > 0, bounds.width > 0, bounds.height > 0 else {
            return
        }

        let imageScaleX = CGFloat(sourceImage.width) / bounds.width
        let imageScaleY = CGFloat(sourceImage.height) / bounds.height
        let cropRect = CGRect(
            x: clipBounds.minX * imageScaleX,
            y: clipBounds.minY * imageScaleY,
            width: clipBounds.width * imageScaleX,
            height: clipBounds.height * imageScaleY
        ).integral

        let input = CIImage(cgImage: sourceImage).cropped(to: cropRect)
        let output: CIImage?

        switch mode {
        case .gaussianBlur:
            let filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(input, forKey: kCIInputImageKey)
            filter?.setValue(12, forKey: kCIInputRadiusKey)
            output = filter?.outputImage?.cropped(to: cropRect)
        case .mosaic:
            let filter = CIFilter(name: "CIPixellate")
            filter?.setValue(input, forKey: kCIInputImageKey)
            filter?.setValue(18, forKey: kCIInputScaleKey)
            output = filter?.outputImage?.cropped(to: cropRect)
        case .singleColor:
            output = nil
        }

        guard let output, let cgImage = ciContext.createCGImage(output, from: cropRect) else {
            return
        }

        context.saveGState()
        path.addClip()
        context.draw(cgImage, in: clipBounds)
        context.restoreGState()
    }

    private var hoverOrActiveMosaicTarget: AnnotationResizeTarget {
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

        guard case let .mosaic(_, currentProps) = annotations[activeMosaicIndex] else {
            return
        }

        let updatedRect = updatedMosaicRect(
            from: startRect,
            startPoint: startPoint,
            currentPoint: point,
            target: activeMosaicTarget
        )
        annotations[activeMosaicIndex] = .mosaic(updatedRect, currentProps)
    }

    private func updateMosaicHover(at point: CGPoint) {
        let previous = hoverMosaicTarget
        hoverMosaicTarget = mosaicInteraction(at: point)?.target ?? .none
        if previous != hoverMosaicTarget || activeMosaicTarget != .none {
            applyCursorForCurrentState()
        }
    }

    private func updateRectHover(at point: CGPoint) {
        let previous = hoverRectTarget
        hoverRectTarget = rectangleInteraction(at: point)?.target ?? .none
        if previous != hoverRectTarget || activeRectTarget != .none {
            applyCursorForCurrentState()
        }
    }

    private func applyCursorForCurrentState() {
        let target: AnnotationResizeTarget
        if currentTool == .mosaic {
            target = hoverOrActiveMosaicTarget
        } else if currentTool == .rectangle {
            target = hoverOrActiveRectTarget
        } else {
            NSCursor.crosshair.set()
            return
        }
        if target == .move {
            let isActive = (currentTool == .mosaic ? activeMosaicTarget : activeRectTarget) == .move
            (isActive ? NSCursor.closedHand : NSCursor.openHand).set()
        } else {
            cursor(for: target).set()
        }
    }

    private func cursor(for target: AnnotationResizeTarget) -> NSCursor {
        switch target {
        case .move:
            return .openHand
        case .resizeLeft, .resizeRight:
            return .resizeLeftRight
        case .resizeTop, .resizeBottom:
            return .resizeUpDown
        case .resizeTopLeft, .resizeBottomRight:
            return .resizeNorthWestSouthEast
        case .resizeTopRight, .resizeBottomLeft:
            return .resizeNorthEastSouthWest
        case .none:
            return .crosshair
        }
    }

    private var hoverOrActiveRectTarget: AnnotationResizeTarget {
        activeRectTarget != .none ? activeRectTarget : hoverRectTarget
    }



    private func updatedMosaicRect(
        from rect: CGRect,
        startPoint: CGPoint,
        currentPoint: CGPoint,
        target: AnnotationResizeTarget
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

    private func mosaicInteraction(at point: CGPoint) -> (index: Int, rect: CGRect, target: AnnotationResizeTarget)? {
        guard currentTool == .mosaic else {
            return nil
        }

        for index in annotations.indices.reversed() {
            guard case let .mosaic(rect, _) = annotations[index] else {
                continue
            }

            let target = mosaicInteractionTarget(for: point, in: rect.standardized)
            if target != .none {
                return (index, rect.standardized, target)
            }
        }

        return nil
    }

    private func rectangleInteraction(at point: CGPoint) -> (index: Int, rect: CGRect, target: AnnotationResizeTarget)? {
        guard let selectedIndex = selectedAnnotationIndex,
              annotations.indices.contains(selectedIndex),
              case let .rectangle(rect, _) = annotations[selectedIndex] else {
            return nil
        }

        let standardizedRect = rect.standardized
        let target = rectangleInteractionTarget(for: point, in: standardizedRect)
        if target != .none {
            return (selectedIndex, standardizedRect, target)
        }

        return nil
    }

    private func rectangleInteractionTarget(for point: CGPoint, in rect: CGRect) -> AnnotationResizeTarget {
        let controlPoints = resizeControlPoints(for: rect)
        let hitRadius: CGFloat = 12

        for (i, cp) in controlPoints.enumerated() {
            if hypot(point.x - cp.x, point.y - cp.y) <= hitRadius {
                switch i {
                case 0: return .resizeBottomLeft
                case 1: return .resizeBottom
                case 2: return .resizeBottomRight
                case 3: return .resizeRight
                case 4: return .resizeTopRight
                case 5: return .resizeTop
                case 6: return .resizeTopLeft
                case 7: return .resizeLeft
                default: return .none
                }
            }
        }

        if rect.insetBy(dx: -6, dy: -6).contains(point) {
            return .move
        }

        return .none
    }

    // MARK: - Multi-Tool Hit Testing

    private struct EditableAnnotationHit {
        let index: Int
        let tool: AnnotationTool
        let properties: AnnotationEditableProperties
    }

    private func hitTestEditableAnnotation(at point: CGPoint) -> EditableAnnotationHit? {
        for index in annotations.indices.reversed() {
            switch annotations[index] {
            case let .rectangle(rect, properties):
                if rect.standardized.contains(point) {
                    return EditableAnnotationHit(index: index, tool: .rectangle, properties: .rectangle(properties))
                }
            case let .ellipse(rect, properties):
                if rect.standardized.insetBy(dx: -6, dy: -6).contains(point) {
                    return EditableAnnotationHit(index: index, tool: .ellipse, properties: .ellipse(properties))
                }
            case let .line(start, end, properties):
                if isPoint(point, nearLineFrom: start, to: end, tolerance: max(8, properties.lineWidth + 4)) {
                    return EditableAnnotationHit(index: index, tool: .line, properties: .line(properties))
                }
            case let .arrow(start, end, properties):
                if isPoint(point, nearArrowFrom: start, to: end, properties: properties) {
                    return EditableAnnotationHit(index: index, tool: .arrow, properties: .arrow(properties))
                }
            case let .pen(points, properties):
                if isPoint(point, nearPolyline: points, tolerance: max(10, properties.lineWidth / 2 + 4)) {
                    return EditableAnnotationHit(index: index, tool: .pen, properties: .pen(properties))
                }
            case let .mosaic(rect, properties):
                if rect.standardized.insetBy(dx: -6, dy: -6).contains(point) {
                    return EditableAnnotationHit(index: index, tool: .mosaic, properties: .mosaic(properties))
                }
            case .text:
                continue
            }
        }

        return nil
    }

    private func isPoint(_ point: CGPoint, nearLineFrom start: CGPoint, to end: CGPoint, tolerance: CGFloat) -> Bool {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y) <= tolerance
        }

        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projection = CGPoint(x: start.x + dx * t, y: start.y + dy * t)
        return hypot(point.x - projection.x, point.y - projection.y) <= tolerance
    }

    private func isPoint(_ point: CGPoint, nearPolyline points: [CGPoint], tolerance: CGFloat) -> Bool {
        guard points.count > 1 else { return false }

        for index in 0..<(points.count - 1) {
            if isPoint(point, nearLineFrom: points[index], to: points[index + 1], tolerance: tolerance) {
                return true
            }
        }

        return false
    }

    private func isPoint(_ point: CGPoint, nearArrowFrom start: CGPoint, to end: CGPoint, properties: ArrowProperties) -> Bool {
        let tolerance = max(10, properties.lineWidth + 6)

        if properties.isCurved {
            return isPoint(point, nearPolyline: curvedArrowBodyPoints(from: start, to: end), tolerance: tolerance)
        }

        return isPoint(point, nearLineFrom: start, to: end, tolerance: tolerance)
    }

    private func curvedArrowBodyPoints(from start: CGPoint, to end: CGPoint, samples: Int = 16) -> [CGPoint] {
        let control = CGPoint(
            x: (start.x + end.x) / 2,
            y: max(start.y, end.y) + min(abs(end.x - start.x), 60)
        )

        return (0...samples).map { index in
            let t = CGFloat(index) / CGFloat(max(samples, 1))
            return cubicBezierPoint(start: start, control1: control, control2: control, end: end, t: t)
        }
    }

    private func cubicBezierPoint(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let oneMinusT = 1 - t
        let oneMinusTSquared = oneMinusT * oneMinusT
        let oneMinusTCubed = oneMinusTSquared * oneMinusT
        let tSquared = t * t
        let tCubed = tSquared * t

        let x =
            oneMinusTCubed * start.x
            + 3 * oneMinusTSquared * t * control1.x
            + 3 * oneMinusT * tSquared * control2.x
            + tCubed * end.x
        let y =
            oneMinusTCubed * start.y
            + 3 * oneMinusTSquared * t * control1.y
            + 3 * oneMinusT * tSquared * control2.y
            + tCubed * end.y

        return CGPoint(x: x, y: y)
    }

    // MARK: - 拖拽移动已选中标注

    private func moveAnnotation(at index: Int, by delta: CGPoint) {
        guard annotations.indices.contains(index) else { return }

        switch annotations[index] {
        case let .rectangle(rect, props):
            annotations[index] = .rectangle(rect.offsetBy(dx: delta.x, dy: delta.y), props)
        case let .ellipse(rect, props):
            annotations[index] = .ellipse(rect.offsetBy(dx: delta.x, dy: delta.y), props)
        case let .line(start, end, props):
            annotations[index] = .line(
                start: CGPoint(x: start.x + delta.x, y: start.y + delta.y),
                end: CGPoint(x: end.x + delta.x, y: end.y + delta.y),
                props
            )
        case let .arrow(start, end, props):
            annotations[index] = .arrow(
                start: CGPoint(x: start.x + delta.x, y: start.y + delta.y),
                end: CGPoint(x: end.x + delta.x, y: end.y + delta.y),
                props
            )
        case let .pen(points, props):
            annotations[index] = .pen(points: points.map { CGPoint(x: $0.x + delta.x, y: $0.y + delta.y) }, props)
        case let .mosaic(rect, props):
            annotations[index] = .mosaic(rect.offsetBy(dx: delta.x, dy: delta.y), props)
        case .text:
            break
        }
    }

    private func updateSelectedRectangle(with point: CGPoint) {
        guard
            let activeRectIndex = activeRectIndex,
            let startPoint = interactionStartMousePoint,
            let startRect = interactionStartRect,
            activeRectTarget != .none,
            annotations.indices.contains(activeRectIndex),
            case .rectangle = annotations[activeRectIndex]
        else {
            return
        }

        guard case let .rectangle(_, currentProps) = annotations[activeRectIndex] else {
            return
        }

        let updatedRect = updatedRectFromResize(
            from: startRect,
            startPoint: startPoint,
            currentPoint: point,
            target: activeRectTarget
        )
        annotations[activeRectIndex] = .rectangle(updatedRect, currentProps)
    }

    private func updatedRectFromResize(
        from rect: CGRect,
        startPoint: CGPoint,
        currentPoint: CGPoint,
        target: AnnotationResizeTarget
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

    private func mosaicInteractionTarget(for point: CGPoint, in rect: CGRect) -> AnnotationResizeTarget {
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

    private func applyTextProperties(_ properties: TextProperties, to textField: NSTextField) {
        textField.font = properties.font
        textField.textColor = properties.textColor
        var frame = textField.frame
        frame.size.height = properties.editorHeight
        textField.frame = frame
    }

    private func style(textField: NSTextField) {
        textField.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.92)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        commitActiveTextIfNeeded()
    }

    private enum AnnotationResizeTarget: Equatable {
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
    static var resizeNorthWestSouthEast: NSCursor {
        NSCursor(
            image: NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: nil) ?? NSImage(),
            hotSpot: NSPoint(x: 8, y: 8)
        )
    }

    static var resizeNorthEastSouthWest: NSCursor {
        NSCursor(
            image: NSImage(systemSymbolName: "arrow.up.right.and.arrow.down.left", accessibilityDescription: nil) ?? NSImage(),
            hotSpot: NSPoint(x: 8, y: 8)
        )
    }
}
