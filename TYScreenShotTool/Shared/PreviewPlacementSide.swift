//
//  PreviewPlacementSide.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/20.
//

enum PreviewPlacementSide {
    case left
    case right

    var opposite: PreviewPlacementSide {
        switch self {
        case .left:
            return .right
        case .right:
            return .left
        }
    }
}
