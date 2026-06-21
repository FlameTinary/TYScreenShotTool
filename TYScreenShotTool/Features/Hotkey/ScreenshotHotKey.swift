//
//  ScreenshotHotKey.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/5.
//

import Carbon

/// 截图快捷键配置
///
/// 定义全局快捷键的键码和修饰符组合，支持存储和显示。
struct ScreenshotHotKey: Equatable {
    /// 快捷键唯一标识
    let id: UInt32
    /// 键码
    let keyCode: UInt32
    /// 修饰符组合
    let modifiers: UInt32

    /// 存储值，用于 UserDefaults 持久化
    var storageValue: String {
        "\(keyCode):\(modifiers)"
    }

    /// 显示名称，包含修饰符符号和按键名称
    var displayName: String {
        modifierDisplayName + (KeyEquivalentNameMap.displayName(for: keyCode) ?? "")
    }

    /// 修饰符显示名称
    ///
    /// 将修饰符转换为对应的符号（⌘⇧⌥⌃）。
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

    /// 初始化快捷键配置
    ///
    /// - Parameters:
    ///   - id: 快捷键唯一标识，默认为 1
    ///   - keyCode: 键码
    ///   - modifiers: 修饰符组合
    init(
        id: UInt32 = 1,
        keyCode: UInt32,
        modifiers: UInt32
    ) {
        self.id = id
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// 默认截图快捷键：⌘⇧2
    static let screenshot = ScreenshotHotKey(
        keyCode: UInt32(kVK_ANSI_2),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    /// 预设快捷键列表
    ///
    /// 提供常用的快捷键选项供用户选择。
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

    /// 从存储值初始化快捷键
    ///
    /// 支持旧版格式（如 "commandShift2"）和新版格式（如 "18:768"）。
    ///
    /// - Parameter storageValue: 存储值字符串
    /// - Returns: 解析成功返回快捷键配置，否则返回 nil
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

    /// 创建候选快捷键
    ///
    /// 验证键码是否在支持范围内，返回有效的快捷键配置。
    ///
    /// - Parameters:
    ///   - keyCode: 键码
    ///   - modifiers: 修饰符组合
    /// - Returns: 有效返回快捷键配置，否则返回 nil
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
