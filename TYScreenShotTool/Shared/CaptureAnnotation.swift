//
//  CaptureAnnotation.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/7.
//

import CoreGraphics
import Foundation

enum CaptureAnnotation: Equatable {
    case rectangle(CGRect)
    case ellipse(CGRect)
    case arrow(start: CGPoint, end: CGPoint)
    case pen(points: [CGPoint])
    case mosaic(CGRect)
    case text(value: String, origin: CGPoint)

    static let strokeColor = CGColor(red: 0.93, green: 0.24, blue: 0.21, alpha: 1)
    static let lineWidth: CGFloat = 3
    static let fontSize: CGFloat = 22
    static let mosaicBlurRadius: CGFloat = 18
    static let mosaicOverlayAlpha: CGFloat = 0.10
    static let mosaicCornerRadius: CGFloat = 6

    var bounds: CGRect {
        switch self {
        case let .rectangle(rect), let .ellipse(rect), let .mosaic(rect):
            return rect.standardized
        case let .arrow(start, end):
            return CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            ).insetBy(dx: -12, dy: -12)
        case let .pen(points):
            guard let first = points.first else {
                return .zero
            }

            return points.dropFirst().reduce(
                CGRect(origin: first, size: .zero).insetBy(dx: -6, dy: -6)
            ) { partialResult, point in
                partialResult.union(CGRect(origin: point, size: .zero).insetBy(dx: -6, dy: -6))
            }
        case let .text(value, origin):
            let width = max(CGFloat(value.count) * CaptureAnnotation.fontSize * 0.6, CaptureAnnotation.fontSize)
            return CGRect(
                x: origin.x,
                y: origin.y,
                width: width,
                height: CaptureAnnotation.fontSize * 1.4
            )
        }
    }
}
