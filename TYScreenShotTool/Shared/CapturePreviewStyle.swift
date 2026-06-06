//
//  CapturePreviewStyle.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/6.
//

import Foundation

struct CapturePreviewStyle {
    var showsRoundedCorners: Bool
    var showsShadow: Bool

    static let `default` = CapturePreviewStyle(
        showsRoundedCorners: false,
        showsShadow: false
    )
}
