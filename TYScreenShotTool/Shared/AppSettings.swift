//
//  AppSettings.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/6.
//

import Foundation

/// 应用设置配置
///
/// 定义应用偏好设置的键名和默认值，统一管理 UserDefaults 存储。
enum AppSettings {
    /// 截图快捷键配置键
    static let screenshotHotKeyKey = "settings.screenshotHotKey"
    /// 截图快捷键默认值
    static let screenshotHotKeyDefaultValue = ScreenshotHotKey.screenshot.storageValue
    /// 保存目录路径键（已废弃，使用书签方式）
    static let saveDirectoryPathKey = "settings.saveDirectoryPath"
    /// 保存目录书签数据键
    static let saveDirectoryBookmarkDataKey = "settings.saveDirectoryBookmarkData"
    /// AI 使用 Vision 文字提取开关键
    static let aiUseVisionTextExtractionKey = "settings.aiUseVisionTextExtraction"
    /// AI 使用 Vision 文字提取默认值
    static let aiUseVisionTextExtractionDefaultValue = false
    /// App 语言设置键
    static let appLanguageKey = "settings.appLanguage"
    /// App 语言默认值
    static let appLanguageDefaultValue = AppLanguage.system.storageValue
    /// App 外观设置键
    static let appAppearanceKey = "settings.appAppearance"
    /// App 外观默认值
    static let appAppearanceDefaultValue = AppAppearance.system.storageValue
    /// AI 分析 API 密钥
    static let aiAnalysisAPIKeyKey = "local.aiAnalysis.openAIAPIKey"
    /// AI 分析 API 基础 URL
    static let aiAnalysisBaseURLKey = "local.aiAnalysis.baseURL"
    /// AI 分析模型名称
    static let aiAnalysisModelKey = "local.aiAnalysis.model"
    /// AI 分析 API 基础 URL 默认值
    static let aiAnalysisBaseURLDefaultValue = "https://api.openai.com"
    /// AI 分析模型默认值
    static let aiAnalysisModelDefaultValue = "gpt-5.4-mini"
    /// 是否显示 AI 功能入口（控制工具栏中的 AI 按钮显示/隐藏）
    static let showAIEntrancesKey = "settings.showAIEntrances"
    /// 显示 AI 功能入口默认值（默认关闭，出于合规考虑）
    static let showAIEntrancesDefaultValue = false

    /// Release 模式下永远返回 false；Debug 模式下先经过区域策略，再读取 UserDefaults 开关。
    ///
    /// Release 构建时即使 UserDefaults 意外写入 true，此方法也返回 false，
    /// Debug 构建时即使手动写入 true，也不能绕过区域策略显示商业 AI 入口。
    static var effectiveShowAIEntrances: Bool {
        #if DEBUG
        return AIAvailabilityService().shouldShowCommercialAIEntry
        #else
        return false
        #endif
    }
}
