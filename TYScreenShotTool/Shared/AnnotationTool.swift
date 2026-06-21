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
    var rawIdentifier: String {
        switch self {
        case .rectangle:
            return "rectangle"
        case .ellipse:
            return "ellipse"
        case .arrow:
            return "arrow"
        case .pen:
            return "pen"
        case .mosaic:
            return "mosaic"
        case .text:
            return "text"
        }
    }

    var title: String {
        switch self {
        case .rectangle:
            return AppText.annotationRectangle
        case .ellipse:
            return AppText.annotationEllipse
        case .arrow:
            return AppText.annotationArrow
        case .pen:
            return AppText.annotationPen
        case .mosaic:
            return AppText.annotationMosaic
        case .text:
            return AppText.annotationText
        }
    }

    var symbolName: String {
        switch self {
        case .rectangle:
            return "rectangle"
        case .ellipse:
            return "circle"
        case .arrow:
            return "arrow.up.right"
        case .pen:
            return "pencil.and.scribble"
        case .mosaic:
            return "rectangle.pattern.checkered"
        case .text:
            return "square.and.pencil"
        }
    }
}
