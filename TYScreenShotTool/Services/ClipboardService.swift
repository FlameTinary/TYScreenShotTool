//
//  ClipboardService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/6.
//

import AppKit
import CoreGraphics
import Foundation

/// 剪贴板服务
///
/// 提供将图像和文本复制到系统剪贴板的功能。
final class ClipboardService {
    /// 将图像复制到剪贴板
    ///
    /// - Parameter image: 要复制的 CGImage
    /// - Throws: `ClipboardError.writeFailed` 如果写入剪贴板失败
    func copyImage(_ image: CGImage) throws {
        let pasteboard = NSPasteboard.general
        let nsImage = NSImage(cgImage: image, size: .zero)

        pasteboard.clearContents()

        guard pasteboard.writeObjects([nsImage]) else {
            throw ClipboardError.writeFailed
        }
    }

    /// 将文本复制到剪贴板
    ///
    /// - Parameter text: 要复制的文本
    /// - Throws: `ClipboardError.writeFailed` 如果写入剪贴板失败
    func copyText(_ text: String) throws {
        let pasteboard = NSPasteboard.general

        pasteboard.clearContents()

        guard pasteboard.setString(text, forType: .string) else {
            throw ClipboardError.writeFailed
        }
    }
}

/// 剪贴板错误类型
///
/// 定义剪贴板操作可能发生的错误。
enum ClipboardError: LocalizedError {
    /// 写入剪贴板失败
    case writeFailed

    /// 错误的本地化描述
    var errorDescription: String? {
        switch self {
        case .writeFailed:
            return "Failed to write image to clipboard."
        }
    }
}
