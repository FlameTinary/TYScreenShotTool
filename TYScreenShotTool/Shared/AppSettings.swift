//
//  AppSettings.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/6.
//

import Foundation

enum AppSettings {
    static let isOCREnabledKey = "settings.isOCREnabled"
    static let isOCREnabledDefaultValue = false
    static let screenshotHotKeyKey = "settings.screenshotHotKey"
    static let screenshotHotKeyDefaultValue = "commandShift2"
    static let saveDirectoryPathKey = "settings.saveDirectoryPath"
    static let saveDirectoryBookmarkDataKey = "settings.saveDirectoryBookmarkData"
}
