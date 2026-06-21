//
//  PreviewPlacementSide.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/20.
//

/// 预览窗口放置位置
///
/// 定义预览窗口相对于选区的放置方向，支持左侧或右侧。
enum PreviewPlacementSide {
    /// 放置在左侧
    case left
    /// 放置在右侧
    case right

    /// 相反的放置位置
    ///
    /// 当一侧空间不足时，可切换到另一侧。
    var opposite: PreviewPlacementSide {
        switch self {
        case .left:
            return .right
        case .right:
            return .left
        }
    }
}
