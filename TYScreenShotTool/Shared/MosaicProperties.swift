//
//  MosaicProperties.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/23.
//

import Foundation

/// 马赛克样式
enum MosaicStyle: String, CaseIterable, Equatable {
    /// 马赛克
    case mosaic
    /// 毛玻璃
    case glass
}

/// 马赛克标注的样式属性
struct MosaicProperties: Equatable {
    var size: CGFloat
    var style: MosaicStyle

    static let `default` = MosaicProperties(
        size: 2,
        style: .glass
    )
}
