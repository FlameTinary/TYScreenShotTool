//
//  AppAppearance.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/21.
//

import AppKit

/// 应用外观模式
enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    var storageValue: String {
        rawValue
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}
