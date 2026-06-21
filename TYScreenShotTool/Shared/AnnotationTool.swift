//
//  AnnotationTool.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/7.
//

import Foundation

enum AnnotationTool: CaseIterable, Equatable {
    case rectangle
    case ellipse
    case arrow
    case pen
    case mosaic
    case text

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
