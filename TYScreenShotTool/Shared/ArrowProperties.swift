//
//  ArrowProperties.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/23.
//

import Foundation

/// 箭头标注的样式属性
struct ArrowProperties: Equatable {
    var lineWidth: CGFloat
    var opacity: CGFloat
    var color: RGBColor
    var isCurved: Bool
    /// 曲线箭头贝塞尔控制点 P1（仅在 isCurved=true 时有意义）
    var curveControl1: CGPoint?
    /// 曲线箭头贝塞尔控制点 P2（仅在 isCurved=true 时有意义）
    var curveControl2: CGPoint?

    static let `default` = ArrowProperties(
        lineWidth: 4,
        opacity: 1.0,
        color: RGBColor(red: 0.0, green: 0.48, blue: 1.0),
        isCurved: false
    )

    /// 根据起点和终点计算默认的贝塞尔控制点（单个控制点，产生单弧曲线）
    static func defaultControlPoint(from start: CGPoint, to end: CGPoint) -> CGPoint {
        CGPoint(
            x: (start.x + end.x) / 2,
            y: max(start.y, end.y) + min(abs(end.x - start.x), 60)
        )
    }

    /// 获取有效的贝塞尔控制点，如果未存储则计算默认值
    func effectiveControlPoints(from start: CGPoint, to end: CGPoint) -> (CGPoint, CGPoint) {
        let defaultCP = Self.defaultControlPoint(from: start, to: end)
        return (
            curveControl1 ?? defaultCP,
            curveControl2 ?? defaultCP
        )
    }

    /// 返回设置了默认控制点的新实例（isCurved 为 true 时使用）
    func withDefaultControlPoints(from start: CGPoint, to end: CGPoint) -> ArrowProperties {
        let defaultCP = Self.defaultControlPoint(from: start, to: end)
        var copy = self
        copy.curveControl1 = defaultCP
        copy.curveControl2 = defaultCP
        return copy
    }
}
