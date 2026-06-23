//
//  CaptureAnnotation.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/7.
//

import CoreGraphics
import Foundation

/// 截图标注类型
///
/// 定义截图上可添加的各种标注类型，包括矩形、圆形、箭头、画笔、马赛克和文字。
/// 每种标注类型都包含其几何数据和渲染参数。
enum CaptureAnnotation: Equatable {
    /// 矩形标注（位置 + 样式属性）
    case rectangle(CGRect, RectangleProperties)
    /// 圆形标注
    case ellipse(CGRect, ShapeStrokeProperties)
    /// 直线标注
    case line(start: CGPoint, end: CGPoint, ShapeStrokeProperties)
    /// 箭头标注，包含起点和终点
    case arrow(start: CGPoint, end: CGPoint, ArrowProperties)
    /// 画笔标注，包含一系列点
    case pen(points: [CGPoint], PenProperties)
    /// 马赛克标注
    case mosaic(CGRect, MosaicProperties)
    /// 文字标注，包含文本内容和位置
    case text(value: String, origin: CGPoint)

    /// 标注描边颜色（红色）
    static let strokeColor = CGColor(red: 0.93, green: 0.24, blue: 0.21, alpha: 1)
    /// 标注线条宽度
    static let lineWidth: CGFloat = 3
    /// 文字标注字体大小
    static let fontSize: CGFloat = 22
    /// 马赛克模糊半径
    static let mosaicBlurRadius: CGFloat = 18
    /// 马赛克覆盖层透明度
    static let mosaicOverlayAlpha: CGFloat = 0.10
    /// 马赛克区域圆角半径
    static let mosaicCornerRadius: CGFloat = 6

    /// 标注的边界矩形
    ///
    /// 计算标注在画布上占据的区域，用于渲染和碰撞检测。
    var bounds: CGRect {
        switch self {
        case let .rectangle(rect, _):
            return rect.standardized
        case let .ellipse(rect, _):
            return rect.standardized
        case let .line(start, end, props):
            let inset = max(8, props.lineWidth + 4)
            return CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            ).insetBy(dx: -inset, dy: -inset)
        case let .mosaic(rect, _):
            return rect.standardized
        case let .arrow(start, end, props):
            let inset = max(12, props.lineWidth + 8)
            return CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            ).insetBy(dx: -inset, dy: -inset)
        case let .pen(points, props):
            guard let first = points.first else {
                return .zero
            }

            let inset = max(6, props.lineWidth / 2 + 4)
            return points.dropFirst().reduce(
                CGRect(origin: first, size: .zero).insetBy(dx: -inset, dy: -inset)
            ) { partialResult, point in
                partialResult.union(CGRect(origin: point, size: .zero).insetBy(dx: -inset, dy: -inset))
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
