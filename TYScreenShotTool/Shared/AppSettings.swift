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
    /// 显示 AI 功能入口默认值（区域策略仍会在中国大陆和 unknown storefront 下隐藏入口）
    static let showAIEntrancesDefaultValue = true
    /// Debug 区域策略 storefront 覆盖值，用于本地验证 CHN / USA / unknown。
    static let debugStorefrontCodeOverrideKey = "debug.regionPolicy.storefrontCode"

    /// 最近一次从 StoreKit 读取到的 storefront code，用于启动后快速判断区域策略。
    static let cachedStorefrontCodeKey = "regionPolicy.cachedStorefrontCode"
    /// Debug StoreKit 验证模式，仅用于本地验证 AI Pro 商品加载 / 购买 / 恢复。
    static let debugStoreKitVerificationModeKey = "debug.storeKitVerificationMode"
    /// Debug StoreKit 测试开关，仅用于本机签名环境下的购买验证。
    static let debugRunStoreKitSandboxTestsKey = "debug.runStoreKitSandboxTests"

    // MARK: - AI Pro Backend

    /// 后端 API 基础 URL
    static let backendBaseURLKey = "settings.backendBaseURL"
    /// 后端 API 基础 URL 默认值。
    ///
    /// Debug 构建默认连接本机 `wrangler dev --env dev`，该 Worker dev 环境再连接本地 Supabase。
    /// Release 构建默认连接正式 Cloudflare Worker，避免正式用户误连本地或开发服务。
    #if DEBUG
    static let backendBaseURLDefaultValue = "http://127.0.0.1:8787"
    #else
    static let backendBaseURLDefaultValue = "https://tshot-ai-backend.tshot.workers.dev"
    #endif
    /// AI Pro 订阅状态缓存，用于启动后快速判断工具栏 AI 入口权限。
    static let aiProSubscriptionStatusCacheKey = "aiPro.subscriptionStatusCache"

    // MARK: - AI Pro First Use Consent

    /// 首次使用 AI Pro 是否已同意数据上传提示
    static let aiFirstUseConsentKey = "settings.aiFirstUseConsent"
    /// 首次使用 AI Pro 同意状态默认值
    static let aiFirstUseConsentDefaultValue = false

    /// 先经过区域策略，再读取用户入口开关。
    ///
    /// 即使手动写入 true，也不能绕过区域策略显示商业 AI 入口。
    static var effectiveShowAIEntrances: Bool {
        AIAvailabilityService().shouldShowAIProShellEntry
    }

    static func boolValue(
        forKey key: String,
        defaultValue: Bool,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        guard userDefaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return userDefaults.bool(forKey: key)
    }
}
