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

    /// 计算直线段上三等分位置的两个点，作为曲线箭头的初始控制点
    /// - 第一个控制点位于线段 1/3 处
    /// - 第二个控制点位于线段 2/3 处
    /// 初始状态下两个控制点落在直线上，箭头显示为直线
    /// 用户拖动控制点离开直线后，箭头变为曲线
    private static func straightLineControlPoints(from start: CGPoint, to end: CGPoint) -> (CGPoint, CGPoint) {
        (
            CGPoint(
                x: start.x + (end.x - start.x) / 3,
                y: start.y + (end.y - start.y) / 3
            ),
            CGPoint(
                x: start.x + 2 * (end.x - start.x) / 3,
                y: start.y + 2 * (end.y - start.y) / 3
            )
        )
    }

    /// 获取有效的贝塞尔控制点，如果未存储则计算线段三等分位置的默认值
    func effectiveControlPoints(from start: CGPoint, to end: CGPoint) -> (CGPoint, CGPoint) {
        let defaults = Self.straightLineControlPoints(from: start, to: end)
        return (
            curveControl1 ?? defaults.0,
            curveControl2 ?? defaults.1
        )
    }

    /// 返回设置了直线段三等分初始控制点的新实例（isCurved 为 true 时使用）
    func withDefaultControlPoints(from start: CGPoint, to end: CGPoint) -> ArrowProperties {
        let (cp1, cp2) = Self.straightLineControlPoints(from: start, to: end)
        var copy = self
        copy.curveControl1 = cp1
        copy.curveControl2 = cp2
        return copy
    }
}
