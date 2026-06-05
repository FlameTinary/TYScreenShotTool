//
//  ScreenshotHotKey.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/5.
//

import Carbon

struct ScreenshotHotKey {
    let id: UInt32
    let keyCode: UInt32
    let modifiers: UInt32

    static let screenshot = ScreenshotHotKey(
        id: 1,
        keyCode: UInt32(kVK_ANSI_2),
        modifiers: UInt32(cmdKey | shiftKey)
    )
}
