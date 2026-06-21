//
//  AnnotationTool.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/7.
//

import Foundation

/// 标注工具类型
///
/// 定义截图编辑态中可用的标注工具，支持工具栏切换。
enum AnnotationTool: CaseIterable, Equatable {
    /// 矩形工具
    case rectangle
    /// 圆形工具
    case ellipse
    /// 箭头工具
    case arrow
    /// 画笔工具
    case pen
    /// 马赛克工具
    case mosaic
    /// 文字工具
    case text

    /// 工具的中文标题
    ///
    /// 用于工具栏按钮显示。
    var title: String {
        switch self {
        case .rectangle:
            return "矩形"
        case .ellipse:
            return "圆形"
        case .arrow:
            return "箭头"
        case .pen:
            return "画笔"
        case .mosaic:
            return "马赛克"
        case .text:
            return "文字"
        }
    }
}
