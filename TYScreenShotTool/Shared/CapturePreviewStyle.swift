//
//  CapturePreviewStyle.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/6.
//

import Foundation

struct CapturePreviewStyle {
    var cornerRadius: CGFloat
    var showsShadow: Bool

    static let `default` = CapturePreviewStyle(
        cornerRadius: 0,
        showsShadow: false
    )
}
