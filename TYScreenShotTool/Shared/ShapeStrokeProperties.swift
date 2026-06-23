//
//  ShapeStrokeProperties.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/23.
//

import Foundation

/// 圆形/直线共用描边属性
struct ShapeStrokeProperties: Equatable {
    var lineWidth: CGFloat
    var opacity: CGFloat
    var color: RGBColor

    static let `default` = ShapeStrokeProperties(
        lineWidth: 3,
        opacity: 1.0,
        color: RGBColor(red: 0.93, green: 0.24, blue: 0.21)
    )
}
