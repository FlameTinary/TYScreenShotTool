//
//  RGBColor.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/21.
//

import AppKit

/// Equatable 颜色值，用于矩形属性持久化和比较
struct RGBColor: Equatable {
    var red: CGFloat   // 0.0-1.0
    var green: CGFloat
    var blue: CGFloat

    /// 转换为 NSColor
    func toNSColor() -> NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    /// 转换为 CGColor
    func toCGColor() -> CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    /// 预设 8 色：红/橙/黄/绿/蓝/紫/白/黑
    static let presetColors: [RGBColor] = [
        RGBColor(red: 0.93, green: 0.24, blue: 0.21),   // 红
        RGBColor(red: 1.00, green: 0.58, blue: 0.00),   // 橙
        RGBColor(red: 1.00, green: 0.80, blue: 0.00),   // 黄
        RGBColor(red: 0.20, green: 0.78, blue: 0.35),   // 绿
        RGBColor(red: 0.00, green: 0.48, blue: 1.00),   // 蓝
        RGBColor(red: 0.69, green: 0.32, blue: 0.87),   // 紫
        RGBColor(red: 1.00, green: 1.00, blue: 1.00),   // 白
        RGBColor(red: 0.00, green: 0.00, blue: 0.00),   // 黑
    ]
}
