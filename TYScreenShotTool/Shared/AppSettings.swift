//
//  AppSettings.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/6.
//

import Foundation

enum AppSettings {
    static let screenshotHotKeyKey = "settings.screenshotHotKey"
    static let screenshotHotKeyDefaultValue = ScreenshotHotKey.screenshot.storageValue
    static let saveDirectoryPathKey = "settings.saveDirectoryPath"
    static let saveDirectoryBookmarkDataKey = "settings.saveDirectoryBookmarkData"
    static let aiUseVisionTextExtractionKey = "settings.aiUseVisionTextExtraction"
    static let aiUseVisionTextExtractionDefaultValue = false
    static let aiAnalysisAPIKeyKey = "local.aiAnalysis.openAIAPIKey"
    static let aiAnalysisBaseURLKey = "local.aiAnalysis.baseURL"
    static let aiAnalysisModelKey = "local.aiAnalysis.model"
    static let aiAnalysisBaseURLDefaultValue = "https://api.openai.com"
    static let aiAnalysisModelDefaultValue = "gpt-5.4-mini"
}
