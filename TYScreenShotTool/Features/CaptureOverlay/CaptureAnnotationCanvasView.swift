//
//  CaptureAnnotationCanvasView.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/7.
//

import AppKit
import CoreText

final class CaptureAnnotationCanvasView: NSView, NSTextFieldDelegate {
    var annotationsDidChange: (([CaptureAnnotation]) -> Void)?

    var currentTool: AnnotationTool? {
        didSet {
            if oldValue != currentTool {
                cancelActiveTextInput()
                temporaryAnnotation = nil
                needsDisplay = true
            }
        }
    }

    private(set) var annotations: [CaptureAnnotation] = []

    private var dragStartPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var temporaryAnnotation: CaptureAnnotation?
    private var activeTextField: NSTextField?
    private var activeTextOrigin: CGPoint?

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

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        for annotation in annotations {
            draw(annotation: annotation)
        }

        if let temporaryAnnotation {
            draw(annotation: temporaryAnnotation)
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
        case .rectangle, .ellipse, .arrow, .mosaic:
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
        case .rectangle, .ellipse, .arrow, .mosaic:
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
        case .rectangle, .ellipse, .arrow, .mosaic:
            finalizeDragAnnotation()
        case .pen:
            finalizePenAnnotation()
        case .text, .none:
            break
        }
    }

    func resetAnnotations() {
        cancelActiveTextInput()
        annotations.removeAll()
        dragStartPoint = nil
        currentPoint = nil
        temporaryAnnotation = nil
        annotationsDidChange?(annotations)
        needsDisplay = true
    }

    func undoLastAnnotation() {
        commitActiveTextIfNeeded()

        guard annotations.isEmpty == false else {
            return
        }

        _ = annotations.removeLast()
        annotationsDidChange?(annotations)
        needsDisplay = true
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
        textField.backgroundColor = NSColor.black.withAlphaComponent(0.18)
        textField.isBordered = false
        textField.focusRingType = .none
        textField.drawsBackground = true
        textField.placeholderString = "输入文字"
        textField.alignment = .left
        textField.target = self
        textField.action = #selector(commitTextInput)

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
        case let .rectangle(rect), let .ellipse(rect), let .mosaic(rect):
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
    }

    private func makeDragAnnotation(from start: CGPoint, to end: CGPoint) -> CaptureAnnotation? {
        switch currentTool {
        case .rectangle:
            return .rectangle(normalizedRect(from: start, to: end))
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

    private func draw(annotation: CaptureAnnotation) {
        switch annotation {
        case let .rectangle(rect):
            let path = NSBezierPath(rect: rect.standardized)
            configureStroke()
            path.lineWidth = CaptureAnnotation.lineWidth
            path.stroke()
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

        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        NSColor.white.withAlphaComponent(0.14).setFill()
        path.fill()

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.white.withAlphaComponent(0.22)
        shadow.shadowBlurRadius = 10
        shadow.shadowOffset = .zero
        shadow.set()
        NSColor.white.withAlphaComponent(0.18).setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    @objc
    private func commitTextInput() {
        commitActiveTextIfNeeded()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        commitActiveTextIfNeeded()
    }
}
