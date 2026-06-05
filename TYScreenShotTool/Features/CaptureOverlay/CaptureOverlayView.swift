//
//  CaptureOverlayView.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/5.
//

import AppKit

final class CaptureOverlayView: NSView {
    var onCancel: (() -> Void)?
    var onSelection: ((CGRect) -> Void)?

    private var dragStartPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isDragging = false

    override var acceptsFirstResponder: Bool {
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
        NSColor.black.withAlphaComponent(0.35).setFill()
        dirtyRect.fill()

        guard let selectionRect else {
            return
        }

        NSColor.white.setStroke()
        let path = NSBezierPath(rect: selectionRect)
        path.lineWidth = 2
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragStartPoint = point
        currentPoint = point
        isDragging = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else {
            return
        }

        let point = constrainedPoint(for: event)
        currentPoint = point
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
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
}
