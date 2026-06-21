//
//  RectangleProperties.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/21.
//

import Foundation

/// 矩形标注的样式属性
struct RectangleProperties: Equatable {
    /// 线宽 1-12px
    var lineWidth: CGFloat
    /// 透明度 0.0-1.0
    var opacity: CGFloat
    /// 圆角 0-100
    var cornerRadius: CGFloat
    /// false=空心（仅描边）, true=实心（填充+描边）
    var isFilled: Bool
    /// 颜色
    var color: RGBColor

    /// 默认值：红色 3px 空心，不透明，无圆角
    static let `default` = RectangleProperties(
        lineWidth: 3,
        opacity: 1.0,
        cornerRadius: 0,
        isFilled: false,
        color: RGBColor(red: 0.93, green: 0.24, blue: 0.21)
    )
}
