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

    static let `default` = ArrowProperties(
        lineWidth: 4,
        opacity: 1.0,
        color: RGBColor(red: 0.0, green: 0.48, blue: 1.0),
        isCurved: false
    )
}
