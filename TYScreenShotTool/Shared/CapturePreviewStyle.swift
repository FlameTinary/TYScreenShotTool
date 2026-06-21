//
//  CapturePreviewStyle.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/6.
//

import Foundation

/// 截图预览样式
///
/// 定义截图导出时的视觉样式配置，如圆角和阴影。
struct CapturePreviewStyle {
    /// 圆角半径
    var cornerRadius: CGFloat
    /// 是否显示阴影
    var showsShadow: Bool

    /// 默认样式：无圆角、无阴影
    static let `default` = CapturePreviewStyle(
        cornerRadius: 0,
        showsShadow: false
    )
}
