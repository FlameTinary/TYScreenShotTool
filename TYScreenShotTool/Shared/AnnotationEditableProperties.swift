//
//  AnnotationEditableProperties.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/23.
//

import Foundation

/// 通用标注选中回显载体
enum AnnotationEditableProperties: Equatable {
    case rectangle(RectangleProperties)
    case ellipse(ShapeStrokeProperties)
    case line(ShapeStrokeProperties)
    case arrow(ArrowProperties)
    case pen(PenProperties)
    case mosaic(MosaicProperties)
    case text(TextProperties)
}
