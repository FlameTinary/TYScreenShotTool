//
//  LocalTranslationService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/27.
//

import Foundation
import Translation

/// 纯本地翻译辅助函数
///
/// 注意：真正的翻译调用在 SwiftUI `.translationTask` 中完成，
/// 本服务只提供中文检测和错误映射等工具方法。
@MainActor
final class LocalTranslationService {
    /// 判断文本是否看起来主要是中文
    /// - Parameter text: 待判断的文本
    /// - Returns: 如果包含足够多的中文字符，返回 true
    static func seemsChineseText(_ text: String) -> Bool {
        let chineseCharacters = text.unicodeScalars.filter {
            $0.value >= 0x4E00 && $0.value <= 0x9FFF
        }.count
        return chineseCharacters > max(3, text.count / 4)
    }

    /// 兜底检测源语言
    ///
    /// 当 Translation.framework 无法自动识别源语言时，
    /// 通过字符统计兜底判断语言类型。
    /// 这不是完美识别，只是给 TranslationSession 提供一个合理的 source hint。
    /// - Parameter text: 待翻译的文本
    /// - Returns: 检测到的语言，无法判断时返回 nil
    static func fallbackSourceLanguage(for text: String) -> Locale.Language? {
        let scalars = text.unicodeScalars

        let chineseCharacters = scalars.filter {
            $0.value >= 0x4E00 && $0.value <= 0x9FFF
        }.count

        let asciiLetters = scalars.filter {
            CharacterSet.letters.contains($0) && $0.value < 128
        }.count

        // 中文字符占比 > 1/4 → 中文
        if chineseCharacters > max(3, text.count / 4) {
            return Locale.Language(identifier: "zh-Hans")
        }

        // ASCII 字母 > 10 个 → 英文
        if asciiLetters > 10 {
            return Locale.Language(identifier: "en")
        }

        return nil
    }

    /// 将本地翻译框架的错误转换为用户友好的提示文案
    /// - Parameter error: 翻译框架抛出的错误
    /// - Returns: 用户友好的错误消息
    static func userFriendlyMessage(for error: Error) -> String {
        let nsError = error as NSError

        TYLogger.debug("error domain: \(nsError.domain)", tag: "LocalTranslation")
        TYLogger.debug("error code: \(nsError.code)", tag: "LocalTranslation")
        TYLogger.debug("error: \(nsError)", tag: "LocalTranslation")

        // 尝试匹配 TranslationError 类型（使用模式匹配 ~=）
        if let translationError = error as? TranslationError {
            if #available(macOS 26.0, *) {
                if case .notInstalled = translationError {
                    return "需要下载本地翻译语言包后才能翻译，请按系统提示下载语言资源后重试。"
                }
                if case .alreadyCancelled = translationError {
                    return AppLocalization.text("translate.failed")
                }
            }
            switch translationError {
            case .unsupportedSourceLanguage, .unsupportedTargetLanguage, .unsupportedLanguagePairing:
                return "当前语言暂不支持本地翻译。"
            case .unableToIdentifyLanguage:
                return "无法识别截图中的语言，请尝试截取更完整、更清晰的文字。"
            case .nothingToTranslate:
                return AppLocalization.text("translate.empty_text")
            case .internalError:
                return "翻译失败，请稍后重试。"
            default:
                break
            }
        }

        // 基于 NSError 信息兜底
        let description = nsError.localizedDescription.lowercased()

        if description.contains("download") || nsError.code == 16 {
            return "需要下载本地翻译语言包后才能翻译，请按系统提示下载语言资源后重试。"
        }
        if description.contains("unsupported") {
            return "当前语言暂不支持本地翻译。"
        }
        if description.contains("identify") {
            return "无法识别截图中的语言，请尝试截取更清晰的文字。"
        }
        if description.contains("nothing") {
            return AppLocalization.text("translate.empty_text")
        }

        return AppLocalization.text("translate.failed")
    }
}
