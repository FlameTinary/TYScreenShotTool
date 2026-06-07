//
//  ScreenshotHotKey.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/5.
//

import Carbon

struct ScreenshotHotKey: Equatable {
    let storageValue: String
    let id: UInt32
    let keyCode: UInt32
    let modifiers: UInt32
    let displayName: String

    init(
        storageValue: String,
        id: UInt32,
        keyCode: UInt32,
        modifiers: UInt32,
        displayName: String
    ) {
        self.storageValue = storageValue
        self.id = id
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayName = displayName
    }

    static let presets: [ScreenshotHotKey] = [
        ScreenshotHotKey(
            storageValue: "commandShift2",
            id: 1,
            keyCode: UInt32(kVK_ANSI_2),
            modifiers: UInt32(cmdKey | shiftKey),
            displayName: "⌘⇧2"
        ),
        ScreenshotHotKey(
            storageValue: "commandShift8",
            id: 1,
            keyCode: UInt32(kVK_ANSI_8),
            modifiers: UInt32(cmdKey | shiftKey),
            displayName: "⌘⇧8"
        ),
        ScreenshotHotKey(
            storageValue: "commandShift9",
            id: 1,
            keyCode: UInt32(kVK_ANSI_9),
            modifiers: UInt32(cmdKey | shiftKey),
            displayName: "⌘⇧9"
        )
    ]

    static let screenshot = presets[0]

    init?(storageValue: String) {
        guard let hotKey = Self.presets.first(where: { $0.storageValue == storageValue }) else {
            return nil
        }

        self = hotKey
    }
}
