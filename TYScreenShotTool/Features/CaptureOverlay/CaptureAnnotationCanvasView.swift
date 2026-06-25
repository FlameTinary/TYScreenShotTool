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
                hoverEllipseTarget = .none
                activeEllipseTarget = .none
                hoverLineTarget = .none
                activeLineTarget = .none
                hoverArrowTarget = .none
                activeArrowTarget = .none
                hoverPenTarget = .none
                activePenTarget = .none
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
    private static let minimumEllipseRadius: CGFloat = 10

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

    private var activeEllipseIndex: Int?
    private var activeEllipseTarget: AnnotationResizeTarget = .none
    private var interactionStartEllipseRect: CGRect?
    private var hoverEllipseTarget: AnnotationResizeTarget = .none

    private var activeLineIndex: Int?
    private var activeLineTarget: AnnotationResizeTarget = .none
    private var interactionStartLineStart: CGPoint?
    private var interactionStartLineEnd: CGPoint?
    private var hoverLineTarget: AnnotationResizeTarget = .none

    // MARK: - 箭头交互状态

    private var activeArrowIndex: Int?
    private var activeArrowTarget: AnnotationResizeTarget = .none
    private var interactionStartArrowStart: CGPoint?
    private var interactionStartArrowEnd: CGPoint?
    private var interactionStartArrowControl1: CGPoint?
    private var interactionStartArrowControl2: CGPoint?
    private var interactionStartArrowIsCurved: Bool = false
    private var hoverArrowTarget: AnnotationResizeTarget = .none

    // MARK: - 画笔交互状态

    private var activePenIndex: Int?
    private var activePenTarget: AnnotationResizeTarget = .none
    private var interactionStartPenPoints: [CGPoint]?
    private var hoverPenTarget: AnnotationResizeTarget = .none

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

        // 椭圆工具：选中椭圆后支持 resize / 移动交互
        if currentTool == .ellipse, let result = ellipseInteraction(at: point) {
            activeEllipseIndex = result.index
            activeEllipseTarget = result.target
            interactionStartMousePoint = point
            interactionStartEllipseRect = result.rect
            hoverEllipseTarget = result.target
            needsDisplay = true
            applyCursorForCurrentState()
            return
        }

        // 线条工具：选中线条后支持端点拖拽交互
        if currentTool == .line, let result = lineInteraction(at: point) {
            activeLineIndex = result.index
            activeLineTarget = result.target
            interactionStartMousePoint = point
            interactionStartLineStart = result.start
            interactionStartLineEnd = result.end
            hoverLineTarget = result.target
            needsDisplay = true
            applyCursorForCurrentState()
            return
        }

        // 箭头工具：选中箭头后支持端点/曲线控制节点拖拽交互
        if currentTool == .arrow, let result = arrowInteraction(at: point) {
            activeArrowIndex = result.index
            activeArrowTarget = result.target
            interactionStartMousePoint = point
            interactionStartArrowStart = result.start
            interactionStartArrowEnd = result.end
            interactionStartArrowControl1 = result.control1
            interactionStartArrowControl2 = result.control2
            if case let .arrow(_, _, props) = annotations[result.index] {
                interactionStartArrowIsCurved = props.isCurved
            }
            hoverArrowTarget = result.target
            needsDisplay = true
            applyCursorForCurrentState()
            return
        }

        // 画笔工具：选中画笔后支持端点拖拽交互
        if currentTool == .pen, let result = penInteraction(at: point) {
            activePenIndex = result.index
            activePenTarget = result.target
            interactionStartMousePoint = point
            interactionStartPenPoints = result.points
            hoverPenTarget = result.target
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

        // 矩形/椭圆工具：选中后支持 resize / 移动交互
        if currentTool == .rectangle, activeRectTarget != .none {
            updateSelectedRectangle(with: point)
            needsDisplay = true
            applyCursorForCurrentState()
            return
        }
        if currentTool == .ellipse, activeEllipseTarget != .none {
            updateSelectedEllipse(with: point)
            needsDisplay = true
            applyCursorForCurrentState()
            return
        }
        if currentTool == .line, activeLineTarget != .none {
            updateSelectedLine(with: point)
            needsDisplay = true
            applyCursorForCurrentState()
            return
        }

        if currentTool == .arrow, activeArrowTarget != .none {
            updateSelectedArrow(with: point)
            needsDisplay = true
            applyCursorForCurrentState()
            return
        }

        if currentTool == .pen, activePenTarget != .none {
            updateSelectedPen(with: point)
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

        // 矩形/椭圆工具：选中后支持 resize / 移动交互
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
        if currentTool == .ellipse, activeEllipseTarget != .none {
            updateSelectedEllipse(with: point)
            activeEllipseIndex = nil
            activeEllipseTarget = .none
            interactionStartMousePoint = nil
            interactionStartEllipseRect = nil
            updateEllipseHover(at: point)
            annotationsDidChange?(annotations)
            applyCursorForCurrentState()
            return
        }
        if currentTool == .line, activeLineTarget != .none {
            updateSelectedLine(with: point)
            activeLineIndex = nil
            activeLineTarget = .none
            interactionStartMousePoint = nil
            interactionStartLineStart = nil
            interactionStartLineEnd = nil
            updateLineHover(at: point)
            annotationsDidChange?(annotations)
            applyCursorForCurrentState()
            return
        }

        if currentTool == .arrow, activeArrowTarget != .none {
            updateSelectedArrow(with: point)
            activeArrowIndex = nil
            activeArrowTarget = .none
            interactionStartMousePoint = nil
            interactionStartArrowStart = nil
            interactionStartArrowEnd = nil
            interactionStartArrowControl1 = nil
            interactionStartArrowControl2 = nil
            interactionStartArrowIsCurved = false
            updateArrowHover(at: point)
            annotationsDidChange?(annotations)
            applyCursorForCurrentState()
            return
        }

        if currentTool == .pen, activePenTarget != .none {
            updateSelectedPen(with: point)
            activePenIndex = nil
            activePenTarget = .none
            interactionStartMousePoint = nil
            interactionStartPenPoints = nil
            updatePenHover(at: point)
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
        updateEllipseHover(at: point)
        updateLineHover(at: point)
        updateArrowHover(at: point)
        updatePenHover(at: point)
    }

    override func cursorUpdate(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateMosaicHover(at: point)
        updateRectHover(at: point)
        updateEllipseHover(at: point)
        updateLineHover(at: point)
        updateArrowHover(at: point)
        updatePenHover(at: point)
    }

    override func mouseExited(with event: NSEvent) {
        hoverMosaicTarget = .none
        hoverRectTarget = .none
        hoverEllipseTarget = .none
        hoverLineTarget = .none
        hoverArrowTarget = .none
        hoverPenTarget = .none
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
        activeEllipseIndex = nil
        activeEllipseTarget = .none
        hoverEllipseTarget = .none
        interactionStartEllipseRect = nil
        activeLineIndex = nil
        activeLineTarget = .none
        hoverLineTarget = .none
        interactionStartLineStart = nil
        interactionStartLineEnd = nil
        activeArrowIndex = nil
        activeArrowTarget = .none
        hoverArrowTarget = .none
        interactionStartArrowStart = nil
        interactionStartArrowEnd = nil
        interactionStartArrowControl1 = nil
        interactionStartArrowControl2 = nil
        interactionStartArrowIsCurved = false
        activePenIndex = nil
        activePenTarget = .none
        hoverPenTarget = .none
        interactionStartPenPoints = nil
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
        case let (.arrow(start, end, currentProps), .arrow(value)):
            var newValue = value
            if value.isCurved && value.curveControl1 == nil {
                // isCurved 从 false 切换到 true 时，使用当前起始/终点计算默认控制点
                newValue = value.withDefaultControlPoints(from: start, to: end)
            } else if !value.isCurved {
                // isCurved 从 true 切换到 false 时，清除控制点
                newValue.curveControl1 = nil
                newValue.curveControl2 = nil
            } else if value.isCurved && currentProps.isCurved {
                // isCurved 保持 true，保留原有的控制点
                newValue.curveControl1 = currentProps.curveControl1
                newValue.curveControl2 = currentProps.curveControl2
            }
            annotations[idx] = .arrow(start: start, end: end, newValue)
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
            let props = currentArrowProperties.isCurved
                ? currentArrowProperties.withDefaultControlPoints(from: start, to: end)
                : currentArrowProperties
            return .arrow(start: start, end: end, props)
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
            let standardizedRect = rect.standardized
            let path = NSBezierPath(ovalIn: standardizedRect)
            props.color.toNSColor().withAlphaComponent(props.opacity).setStroke()
            path.lineWidth = props.lineWidth
            path.stroke()

            // 选中高亮 — 8 个缩放控制点
            if let index, index == selectedAnnotationIndex {
                let controlPoints = ellipseResizeControlPoints(for: standardizedRect)
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
        case let .line(start, end, props):
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            path.lineWidth = props.lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            props.color.toNSColor().withAlphaComponent(props.opacity).setStroke()
            path.stroke()

            // 选中高亮 — 两个端点控制节点
            if let index, index == selectedAnnotationIndex {
                let controlPoints = [start, end]
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
        case let .arrow(start, end, props):
            let path = arrowPath(from: start, to: end, properties: props)
            path.lineWidth = props.lineWidth
            props.color.toNSColor().withAlphaComponent(props.opacity).setStroke()
            path.stroke()

            // 选中高亮 — 控制节点
            if let index, index == selectedAnnotationIndex {
                let controlPoints = arrowControlPoints(start: start, end: end, properties: props)
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
        case let .pen(points, props):
            guard let first = points.first, let last = points.last else { return }

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

            // 选中高亮 — 端点控制节点
            if let index, index == selectedAnnotationIndex {
                let controlPoints = [first, last]
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

    private func arrowPath(from start: CGPoint, to end: CGPoint, properties: ArrowProperties) -> NSBezierPath {
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let arrowEnd: CGPoint
        let arrowAngle: CGFloat

        if properties.isCurved {
            let (control1, control2) = properties.effectiveControlPoints(from: start, to: end)
            path.move(to: start)
            path.curve(to: end, controlPoint1: control1, controlPoint2: control2)
            arrowEnd = end
            // Approximate tangent direction at endpoint
            let tangentDx = end.x - control2.x
            let tangentDy = end.y - control2.y
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

    /// 获取箭头的控制节点列表
    /// - 直线箭头：起点和终点，共 2 个
    /// - 曲线箭头：起点、控制点1、控制点2、终点，共 4 个
    private func arrowControlPoints(start: CGPoint, end: CGPoint, properties: ArrowProperties) -> [CGPoint] {
        if properties.isCurved {
            let (control1, control2) = properties.effectiveControlPoints(from: start, to: end)
            return [start, control1, control2, end]
        }
        return [start, end]
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
        var isActiveMove = false
        if currentTool == .mosaic {
            target = hoverOrActiveMosaicTarget
            isActiveMove = activeMosaicTarget == .move
        } else if currentTool == .rectangle {
            target = hoverOrActiveRectTarget
            isActiveMove = activeRectTarget == .move
        } else if currentTool == .ellipse {
            target = hoverOrActiveEllipseTarget
            isActiveMove = activeEllipseTarget == .move
        } else if currentTool == .line {
            target = hoverOrActiveLineTarget
            isActiveMove = activeLineTarget == .move
        } else if currentTool == .arrow {
            target = hoverOrActiveArrowTarget
            isActiveMove = activeArrowTarget == .move
        } else if currentTool == .pen {
            target = hoverOrActivePenTarget
            isActiveMove = activePenTarget == .move
        } else {
            NSCursor.crosshair.set()
            return
        }
        if target == .move {
            (isActiveMove ? NSCursor.closedHand : NSCursor.openHand).set()
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
        case .resizeLineStart, .resizeLineEnd:
            return .openHand
        case .resizeArrowControl1, .resizeArrowControl2:
            return .openHand
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
        case .resizeLineStart, .resizeLineEnd, .resizeArrowControl1, .resizeArrowControl2, .none:
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

    // MARK: - Ellipse Resize Interaction

    private func ellipseResizeControlPoints(for rect: CGRect) -> [CGPoint] {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2
        let ry = rect.height / 2
        let d: CGFloat = 0.7071067811865475 // cos(45°)

        return [
            CGPoint(x: center.x - rx * d, y: center.y - ry * d), // bottom-left
            CGPoint(x: center.x, y: center.y - ry),               // bottom
            CGPoint(x: center.x + rx * d, y: center.y - ry * d), // bottom-right
            CGPoint(x: center.x + rx, y: center.y),               // right
            CGPoint(x: center.x + rx * d, y: center.y + ry * d), // top-right
            CGPoint(x: center.x, y: center.y + ry),               // top
            CGPoint(x: center.x - rx * d, y: center.y + ry * d), // top-left
            CGPoint(x: center.x - rx, y: center.y),               // left
        ]
    }

    private var hoverOrActiveEllipseTarget: AnnotationResizeTarget {
        activeEllipseTarget != .none ? activeEllipseTarget : hoverEllipseTarget
    }

    private func ellipseInteraction(at point: CGPoint) -> (index: Int, rect: CGRect, target: AnnotationResizeTarget)? {
        guard let selectedIndex = selectedAnnotationIndex,
              annotations.indices.contains(selectedIndex),
              case let .ellipse(rect, _) = annotations[selectedIndex] else {
            return nil
        }

        let standardizedRect = rect.standardized
        let target = ellipseInteractionTarget(for: point, in: standardizedRect)
        if target != .none {
            return (selectedIndex, standardizedRect, target)
        }

        return nil
    }

    private func ellipseInteractionTarget(for point: CGPoint, in rect: CGRect) -> AnnotationResizeTarget {
        let controlPoints = ellipseResizeControlPoints(for: rect)
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

    private func updateEllipseHover(at point: CGPoint) {
        let previous = hoverEllipseTarget
        hoverEllipseTarget = ellipseInteraction(at: point)?.target ?? .none
        if previous != hoverEllipseTarget || activeEllipseTarget != .none {
            applyCursorForCurrentState()
        }
    }

    private func updateSelectedEllipse(with point: CGPoint) {
        guard
            let activeEllipseIndex = activeEllipseIndex,
            let startPoint = interactionStartMousePoint,
            let startRect = interactionStartEllipseRect,
            activeEllipseTarget != .none,
            annotations.indices.contains(activeEllipseIndex),
            case .ellipse = annotations[activeEllipseIndex]
        else {
            return
        }

        guard case let .ellipse(_, currentProps) = annotations[activeEllipseIndex] else {
            return
        }

        let updatedRect = updatedEllipseFromResize(
            from: startRect,
            startPoint: startPoint,
            currentPoint: point,
            target: activeEllipseTarget
        )
        annotations[activeEllipseIndex] = .ellipse(updatedRect, currentProps)
    }

    private func updatedEllipseFromResize(
        from rect: CGRect,
        startPoint: CGPoint,
        currentPoint: CGPoint,
        target: AnnotationResizeTarget
    ) -> CGRect {
        let deltaX = currentPoint.x - startPoint.x
        let deltaY = currentPoint.y - startPoint.y
        let minRadius = Self.minimumEllipseRadius

        switch target {
        case .move:
            return constrainedRect(rect.offsetBy(dx: deltaX, dy: deltaY))
        case .resizeTop:
            var newRect = rect
            newRect.size.height = max(minRadius * 2, rect.size.height + deltaY)
            return constrainedRect(newRect)
        case .resizeBottom:
            var newRect = rect
            newRect.origin.y += deltaY
            newRect.size.height = max(minRadius * 2, rect.size.height - deltaY)
            return constrainedRect(newRect)
        case .resizeLeft:
            var newRect = rect
            newRect.origin.x += deltaX
            newRect.size.width = max(minRadius * 2, rect.size.width - deltaX)
            return constrainedRect(newRect)
        case .resizeRight:
            var newRect = rect
            newRect.size.width = max(minRadius * 2, rect.size.width + deltaX)
            return constrainedRect(newRect)
        case .resizeTopLeft, .resizeTopRight, .resizeBottomLeft, .resizeBottomRight:
            return updatedEllipseFromDiagonalResize(from: rect, startPoint: startPoint, currentPoint: currentPoint, target: target)
        case .resizeLineStart, .resizeLineEnd, .resizeArrowControl1, .resizeArrowControl2, .none:
            return rect
        }
    }

    private func updatedEllipseFromDiagonalResize(
        from rect: CGRect,
        startPoint: CGPoint,
        currentPoint: CGPoint,
        target: AnnotationResizeTarget
    ) -> CGRect {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let initialRx = rect.width / 2
        let initialRy = rect.height / 2
        let minRadius = Self.minimumEllipseRadius

        let startVec = CGPoint(x: startPoint.x - center.x, y: startPoint.y - center.y)
        let currentVec = CGPoint(x: currentPoint.x - center.x, y: currentPoint.y - center.y)
        let startDist = hypot(startVec.x, startVec.y)
        let currentDist = hypot(currentVec.x, currentVec.y)

        guard startDist > 0 else { return rect }

        let scale = max(minRadius / min(initialRx, initialRy), currentDist / startDist)
        let newRx = max(initialRx * scale, minRadius)
        let newRy = max(initialRy * scale, minRadius)

        let newRect = CGRect(
            x: center.x - newRx,
            y: center.y - newRy,
            width: 2 * newRx,
            height: 2 * newRy
        )

        return constrainedRect(newRect)
    }

    // MARK: - Line Resize Interaction

    private var hoverOrActiveLineTarget: AnnotationResizeTarget {
        activeLineTarget != .none ? activeLineTarget : hoverLineTarget
    }

    private func lineResizeControlPoints(start: CGPoint, end: CGPoint) -> [CGPoint] {
        [start, end]
    }

    private func lineInteractionTarget(for point: CGPoint, start: CGPoint, end: CGPoint, lineWidth: CGFloat) -> AnnotationResizeTarget {
        let hitRadius: CGFloat = 12

        if hypot(point.x - start.x, point.y - start.y) <= hitRadius {
            return .resizeLineStart
        }

        if hypot(point.x - end.x, point.y - end.y) <= hitRadius {
            return .resizeLineEnd
        }

        let tolerance = max(8, lineWidth + 4)
        if isPoint(point, nearLineFrom: start, to: end, tolerance: tolerance) {
            return .move
        }

        return .none
    }

    private func lineInteraction(at point: CGPoint) -> (index: Int, start: CGPoint, end: CGPoint, target: AnnotationResizeTarget)? {
        guard let selectedIndex = selectedAnnotationIndex,
              annotations.indices.contains(selectedIndex),
              case let .line(start, end, props) = annotations[selectedIndex] else {
            return nil
        }

        let target = lineInteractionTarget(for: point, start: start, end: end, lineWidth: props.lineWidth)
        if target != .none {
            return (selectedIndex, start, end, target)
        }

        return nil
    }

    private func updateLineHover(at point: CGPoint) {
        let previous = hoverLineTarget
        hoverLineTarget = lineInteraction(at: point)?.target ?? .none
        if previous != hoverLineTarget || activeLineTarget != .none {
            applyCursorForCurrentState()
        }
    }

    private func updateSelectedLine(with point: CGPoint) {
        guard
            let activeLineIndex = activeLineIndex,
            let startPoint = interactionStartMousePoint,
            let startLineStart = interactionStartLineStart,
            let startLineEnd = interactionStartLineEnd,
            activeLineTarget != .none,
            annotations.indices.contains(activeLineIndex),
            case .line = annotations[activeLineIndex]
        else {
            return
        }

        guard case let .line(_, _, currentProps) = annotations[activeLineIndex] else {
            return
        }

        let (newStart, newEnd) = updatedLineFromResize(
            fromStart: startLineStart,
            fromEnd: startLineEnd,
            startPoint: startPoint,
            currentPoint: point,
            target: activeLineTarget
        )
        annotations[activeLineIndex] = .line(start: newStart, end: newEnd, currentProps)
    }

    private func updatedLineFromResize(
        fromStart: CGPoint,
        fromEnd: CGPoint,
        startPoint: CGPoint,
        currentPoint: CGPoint,
        target: AnnotationResizeTarget
    ) -> (start: CGPoint, end: CGPoint) {
        let deltaX = currentPoint.x - startPoint.x
        let deltaY = currentPoint.y - startPoint.y

        switch target {
        case .resizeLineStart:
            let newStart = CGPoint(
                x: min(max(fromStart.x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(fromStart.y + deltaY, bounds.minY), bounds.maxY)
            )
            return (newStart, fromEnd)
        case .resizeLineEnd:
            let newEnd = CGPoint(
                x: min(max(fromEnd.x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(fromEnd.y + deltaY, bounds.minY), bounds.maxY)
            )
            return (fromStart, newEnd)
        case .move:
            let newStart = CGPoint(
                x: min(max(fromStart.x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(fromStart.y + deltaY, bounds.minY), bounds.maxY)
            )
            let newEnd = CGPoint(
                x: min(max(fromEnd.x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(fromEnd.y + deltaY, bounds.minY), bounds.maxY)
            )
            return (newStart, newEnd)
        default:
            return (fromStart, fromEnd)
        }
    }

    // MARK: - Arrow Resize Interaction

    private var hoverOrActiveArrowTarget: AnnotationResizeTarget {
        activeArrowTarget != .none ? activeArrowTarget : hoverArrowTarget
    }

    private func arrowInteraction(at point: CGPoint) -> (index: Int, start: CGPoint, end: CGPoint, control1: CGPoint, control2: CGPoint, target: AnnotationResizeTarget)? {
        guard let selectedIndex = selectedAnnotationIndex,
              annotations.indices.contains(selectedIndex),
              case let .arrow(start, end, props) = annotations[selectedIndex] else {
            return nil
        }

        let (control1, control2) = props.effectiveControlPoints(from: start, to: end)
        let target = arrowInteractionTarget(for: point, start: start, end: end, control1: control1, control2: control2, properties: props)
        if target != .none {
            return (selectedIndex, start, end, control1, control2, target)
        }

        return nil
    }

    private func arrowInteractionTarget(
        for point: CGPoint,
        start: CGPoint,
        end: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        properties: ArrowProperties
    ) -> AnnotationResizeTarget {
        let hitRadius: CGFloat = 12

        if properties.isCurved {
            // 曲线箭头：4 个控制节点 — 按顺序检测：控制点2、控制点1、端点2、端点1
            // (从靠近鼠标的区域优先检测)
            if hypot(point.x - control2.x, point.y - control2.y) <= hitRadius {
                return .resizeArrowControl2
            }
            if hypot(point.x - control1.x, point.y - control1.y) <= hitRadius {
                return .resizeArrowControl1
            }
        }

        // 端点检测（直线和曲线通用）
        if hypot(point.x - end.x, point.y - end.y) <= hitRadius {
            return .resizeLineEnd
        }
        if hypot(point.x - start.x, point.y - start.y) <= hitRadius {
            return .resizeLineStart
        }

        // 箭头主体命中检测
        if isPoint(point, nearArrowFrom: start, to: end, properties: properties) {
            return .move
        }

        return .none
    }

    private func updateArrowHover(at point: CGPoint) {
        let previous = hoverArrowTarget
        hoverArrowTarget = arrowInteraction(at: point)?.target ?? .none
        if previous != hoverArrowTarget || activeArrowTarget != .none {
            applyCursorForCurrentState()
        }
    }

    private func updateSelectedArrow(with point: CGPoint) {
        guard
            let activeArrowIndex = activeArrowIndex,
            let startPoint = interactionStartMousePoint,
            let startArrowStart = interactionStartArrowStart,
            let startArrowEnd = interactionStartArrowEnd,
            let startControl1 = interactionStartArrowControl1,
            let startControl2 = interactionStartArrowControl2,
            activeArrowTarget != .none,
            annotations.indices.contains(activeArrowIndex),
            case .arrow = annotations[activeArrowIndex]
        else {
            return
        }

        guard case let .arrow(_, _, currentProps) = annotations[activeArrowIndex] else {
            return
        }

        let (newStart, newEnd, newControl1, newControl2) = updatedArrowFromResize(
            fromStart: startArrowStart,
            fromEnd: startArrowEnd,
            fromControl1: startControl1,
            fromControl2: startControl2,
            startPoint: startPoint,
            currentPoint: point,
            target: activeArrowTarget,
            isCurved: interactionStartArrowIsCurved
        )

        var newProps = currentProps
        if interactionStartArrowIsCurved {
            newProps.curveControl1 = newControl1
            newProps.curveControl2 = newControl2
        }
        annotations[activeArrowIndex] = .arrow(start: newStart, end: newEnd, newProps)
    }

    private func updatedArrowFromResize(
        fromStart: CGPoint,
        fromEnd: CGPoint,
        fromControl1: CGPoint,
        fromControl2: CGPoint,
        startPoint: CGPoint,
        currentPoint: CGPoint,
        target: AnnotationResizeTarget,
        isCurved: Bool
    ) -> (start: CGPoint, end: CGPoint, control1: CGPoint?, control2: CGPoint?) {
        let deltaX = currentPoint.x - startPoint.x
        let deltaY = currentPoint.y - startPoint.y

        switch target {
        case .resizeLineStart:
            let newStart = CGPoint(
                x: min(max(fromStart.x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(fromStart.y + deltaY, bounds.minY), bounds.maxY)
            )
            // 拖动起始端时，控制点1跟随起始端移动
            let newControl1 = isCurved ? CGPoint(
                x: min(max(fromControl1.x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(fromControl1.y + deltaY, bounds.minY), bounds.maxY)
            ) : nil
            return (newStart, fromEnd, newControl1, isCurved ? fromControl2 : nil)

        case .resizeLineEnd:
            let newEnd = CGPoint(
                x: min(max(fromEnd.x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(fromEnd.y + deltaY, bounds.minY), bounds.maxY)
            )
            // 拖动终止端时，控制点2跟随终止端移动
            let newControl2 = isCurved ? CGPoint(
                x: min(max(fromControl2.x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(fromControl2.y + deltaY, bounds.minY), bounds.maxY)
            ) : nil
            return (fromStart, newEnd, isCurved ? fromControl1 : nil, newControl2)

        case .resizeArrowControl1:
            let newControl1 = CGPoint(
                x: min(max(fromControl1.x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(fromControl1.y + deltaY, bounds.minY), bounds.maxY)
            )
            return (fromStart, fromEnd, newControl1, fromControl2)

        case .resizeArrowControl2:
            let newControl2 = CGPoint(
                x: min(max(fromControl2.x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(fromControl2.y + deltaY, bounds.minY), bounds.maxY)
            )
            return (fromStart, fromEnd, fromControl1, newControl2)

        case .move:
            let newStart = CGPoint(
                x: min(max(fromStart.x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(fromStart.y + deltaY, bounds.minY), bounds.maxY)
            )
            let newEnd = CGPoint(
                x: min(max(fromEnd.x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(fromEnd.y + deltaY, bounds.minY), bounds.maxY)
            )
            let newControl1 = isCurved ? CGPoint(
                x: min(max(fromControl1.x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(fromControl1.y + deltaY, bounds.minY), bounds.maxY)
            ) : nil
            let newControl2 = isCurved ? CGPoint(
                x: min(max(fromControl2.x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(fromControl2.y + deltaY, bounds.minY), bounds.maxY)
            ) : nil
            return (newStart, newEnd, newControl1, newControl2)

        default:
            return (fromStart, fromEnd, isCurved ? fromControl1 : nil, isCurved ? fromControl2 : nil)
        }
    }

    // MARK: - Pen (画笔) Resize Interaction

    private var hoverOrActivePenTarget: AnnotationResizeTarget {
        activePenTarget != .none ? activePenTarget : hoverPenTarget
    }

    private func penInteractionTarget(for point: CGPoint, points: [CGPoint], lineWidth: CGFloat) -> AnnotationResizeTarget {
        guard let first = points.first, let last = points.last else {
            return .none
        }

        let hitRadius: CGFloat = 12

        // 端点仅作为视觉指示器，回到鼠标时即整体移动
        if hypot(point.x - first.x, point.y - first.y) <= hitRadius {
            return .move
        }

        if hypot(point.x - last.x, point.y - last.y) <= hitRadius {
            return .move
        }

        let tolerance = max(10, lineWidth / 2 + 4)
        if isPoint(point, nearPolyline: points, tolerance: tolerance) {
            return .move
        }

        return .none
    }

    private func penInteraction(at point: CGPoint) -> (index: Int, points: [CGPoint], target: AnnotationResizeTarget)? {
        guard let selectedIndex = selectedAnnotationIndex,
              annotations.indices.contains(selectedIndex),
              case let .pen(points, props) = annotations[selectedIndex] else {
            return nil
        }

        let target = penInteractionTarget(for: point, points: points, lineWidth: props.lineWidth)
        if target != .none {
            return (selectedIndex, points, target)
        }

        return nil
    }

    private func updatePenHover(at point: CGPoint) {
        let previous = hoverPenTarget
        hoverPenTarget = penInteraction(at: point)?.target ?? .none
        if previous != hoverPenTarget || activePenTarget != .none {
            applyCursorForCurrentState()
        }
    }

    private func updateSelectedPen(with point: CGPoint) {
        guard
            let activePenIndex = activePenIndex,
            let startPoints = interactionStartPenPoints,
            let startPoint = interactionStartMousePoint,
            activePenTarget != .none,
            annotations.indices.contains(activePenIndex),
            case .pen = annotations[activePenIndex]
        else {
            return
        }

        guard case let .pen(_, currentProps) = annotations[activePenIndex] else {
            return
        }

        let newPoints = updatedPenFromResize(
            fromPoints: startPoints,
            startPoint: startPoint,
            currentPoint: point,
            target: activePenTarget
        )
        annotations[activePenIndex] = .pen(points: newPoints, currentProps)
    }

    private func updatedPenFromResize(
        fromPoints: [CGPoint],
        startPoint: CGPoint,
        currentPoint: CGPoint,
        target: AnnotationResizeTarget
    ) -> [CGPoint] {
        let deltaX = currentPoint.x - startPoint.x
        let deltaY = currentPoint.y - startPoint.y

        switch target {
        case .resizeLineStart:
            guard !fromPoints.isEmpty else { return fromPoints }
            var newPoints = fromPoints
            newPoints[0] = CGPoint(
                x: min(max(newPoints[0].x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(newPoints[0].y + deltaY, bounds.minY), bounds.maxY)
            )
            return newPoints

        case .resizeLineEnd:
            guard !fromPoints.isEmpty else { return fromPoints }
            var newPoints = fromPoints
            let lastIndex = newPoints.count - 1
            newPoints[lastIndex] = CGPoint(
                x: min(max(newPoints[lastIndex].x + deltaX, bounds.minX), bounds.maxX),
                y: min(max(newPoints[lastIndex].y + deltaY, bounds.minY), bounds.maxY)
            )
            return newPoints

        case .move:
            return fromPoints.map { point in
                CGPoint(
                    x: min(max(point.x + deltaX, bounds.minX), bounds.maxX),
                    y: min(max(point.y + deltaY, bounds.minY), bounds.maxY)
                )
            }

        default:
            return fromPoints
        }
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
                // 也检测控制节点区域（让点击控制节点也能选中箭头）
                let hitRadius: CGFloat = 14
                let controls = arrowControlPoints(start: start, end: end, properties: properties)
                for cp in controls {
                    if hypot(point.x - cp.x, point.y - cp.y) <= hitRadius {
                        return EditableAnnotationHit(index: index, tool: .arrow, properties: .arrow(properties))
                    }
                }
            case let .pen(points, properties):
                if isPoint(point, nearPolyline: points, tolerance: max(10, properties.lineWidth / 2 + 4)) {
                    return EditableAnnotationHit(index: index, tool: .pen, properties: .pen(properties))
                }
                // 也检测端点控制节点区域
                let hitRadius: CGFloat = 14
                if let first = points.first, hypot(point.x - first.x, point.y - first.y) <= hitRadius {
                    return EditableAnnotationHit(index: index, tool: .pen, properties: .pen(properties))
                }
                if let last = points.last, hypot(point.x - last.x, point.y - last.y) <= hitRadius {
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
            return isPoint(point, nearPolyline: curvedArrowBodyPoints(from: start, to: end, properties: properties), tolerance: tolerance)
        }

        return isPoint(point, nearLineFrom: start, to: end, tolerance: tolerance)
    }

    private func curvedArrowBodyPoints(from start: CGPoint, to end: CGPoint, properties: ArrowProperties, samples: Int = 16) -> [CGPoint] {
        let (control1, control2) = properties.effectiveControlPoints(from: start, to: end)

        return (0...samples).map { index in
            let t = CGFloat(index) / CGFloat(max(samples, 1))
            return cubicBezierPoint(start: start, control1: control1, control2: control2, end: end, t: t)
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
            var movedProps = props
            if let c1 = props.curveControl1 {
                movedProps.curveControl1 = CGPoint(x: c1.x + delta.x, y: c1.y + delta.y)
            }
            if let c2 = props.curveControl2 {
                movedProps.curveControl2 = CGPoint(x: c2.x + delta.x, y: c2.y + delta.y)
            }
            annotations[index] = .arrow(
                start: CGPoint(x: start.x + delta.x, y: start.y + delta.y),
                end: CGPoint(x: end.x + delta.x, y: end.y + delta.y),
                movedProps
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
        case .resizeLineStart, .resizeLineEnd, .resizeArrowControl1, .resizeArrowControl2, .none:
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
        case resizeLineStart
        case resizeLineEnd
        case resizeArrowControl1
        case resizeArrowControl2
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
