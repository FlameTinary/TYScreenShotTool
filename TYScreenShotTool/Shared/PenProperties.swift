//
//  PenProperties.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/23.
//

import Foundation

/// 画笔模式
enum PenMode: String, CaseIterable, Equatable {
    /// 单一颜色
    case singleColor
    /// 高斯模糊
    case gaussianBlur
    /// 马赛克
    case mosaic
}

/// 画笔标注的样式属性
struct PenProperties: Equatable {
    var lineWidth: CGFloat
    var opacity: CGFloat
    var color: RGBColor
    var mode: PenMode

    static let `default` = PenProperties(
        lineWidth: 16,
        opacity: 1.0,
        color: RGBColor(red: 0.93, green: 0.24, blue: 0.21),
        mode: .singleColor
    )
}
