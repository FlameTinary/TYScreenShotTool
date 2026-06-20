//
//  ScreenshotHotKey.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/5.
//

import Carbon

struct ScreenshotHotKey: Equatable {
    let id: UInt32
    let keyCode: UInt32
    let modifiers: UInt32

    var storageValue: String {
        "\(keyCode):\(modifiers)"
    }

    var displayName: String {
        modifierDisplayName + (KeyEquivalentNameMap.displayName(for: keyCode) ?? "")
    }

    private var modifierDisplayName: String {
        var parts: [String] = []

        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }
        if modifiers & UInt32(controlKey) != 0 {
            parts.append("⌃")
        }

        return parts.joined()
    }

    init(
        id: UInt32 = 1,
        keyCode: UInt32,
        modifiers: UInt32
    ) {
        self.id = id
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    static let screenshot = ScreenshotHotKey(
        keyCode: UInt32(kVK_ANSI_2),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    static let presets: [ScreenshotHotKey] = [
        .screenshot,
        ScreenshotHotKey(
            keyCode: UInt32(kVK_ANSI_8),
            modifiers: UInt32(cmdKey | shiftKey)
        ),
        ScreenshotHotKey(
            keyCode: UInt32(kVK_ANSI_9),
            modifiers: UInt32(cmdKey | shiftKey)
        )
    ]

    init?(storageValue: String) {
        switch storageValue {
        case "commandShift2":
            self = .screenshot
            return
        case "commandShift8":
            self = ScreenshotHotKey(
                keyCode: UInt32(kVK_ANSI_8),
                modifiers: UInt32(cmdKey | shiftKey)
            )
            return
        case "commandShift9":
            self = ScreenshotHotKey(
                keyCode: UInt32(kVK_ANSI_9),
                modifiers: UInt32(cmdKey | shiftKey)
            )
            return
        default:
            break
        }

        let parts = storageValue.split(separator: ":")
        guard parts.count == 2,
              let keyCode = UInt32(parts[0]),
              let modifiers = UInt32(parts[1]),
              KeyEquivalentNameMap.displayName(for: keyCode) != nil else {
            return nil
        }

        self.init(
            keyCode: keyCode,
            modifiers: modifiers
        )
    }

    static func makeCandidate(
        keyCode: UInt32,
        modifiers: UInt32
    ) -> ScreenshotHotKey? {
        guard KeyEquivalentNameMap.displayName(for: keyCode) != nil else {
            return nil
        }

        return ScreenshotHotKey(
            keyCode: keyCode,
            modifiers: modifiers
        )
    }
}
