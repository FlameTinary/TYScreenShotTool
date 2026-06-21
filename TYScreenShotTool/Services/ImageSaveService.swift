//
//  ImageSaveService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/5.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 图像保存服务
///
/// 提供将截图保存到文件系统的功能，支持临时文件保存和移动到用户配置的目录。
final class ImageSaveService {
    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let dateFormatter: DateFormatter

    /// 初始化图像保存服务
    ///
    /// - Parameters:
    ///   - fileManager: 文件管理器实例
    ///   - userDefaults: 用户偏好设置存储
    init(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard
    ) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss-SSS"
        self.dateFormatter = formatter
    }

    /// 将图像保存为临时 PNG 文件
    ///
    /// 在系统临时目录创建 PNG 文件，文件名包含时间戳。
    ///
    /// - Parameter image: 要保存的 CGImage
    /// - Returns: 临时文件的 URL
    /// - Throws: `ImageSaveError.destinationCreationFailed` 如果无法创建文件目标
    /// - Throws: `ImageSaveError.finalizeFailed` 如果无法完成文件写入
    /// - Throws: `ImageSaveError.fileWriteFailed` 如果文件写入失败
    func saveTemporaryPNG(_ image: CGImage) throws -> URL {
        let temporaryURL = temporaryDirectoryURL().appendingPathComponent(fileName(for: Date()))
        try writePNG(image, to: temporaryURL)
        return temporaryURL
    }

    /// 将临时文件移动到用户配置的保存目录
    ///
    /// 使用安全作用域资源访问用户选择的目录，验证目录有效性后移动文件。
    ///
    /// - Parameter temporaryURL: 临时文件的 URL
    /// - Returns: 最终保存位置的 URL
    /// - Throws: `ImageSaveError.saveDirectoryNotConfigured` 如果未配置保存目录
    /// - Throws: `ImageSaveError.directoryBookmarkStale` 如果目录授权已过期
    /// - Throws: `ImageSaveError.configuredDirectoryNotFound` 如果配置的目录不存在
    func moveImageToConfiguredDirectory(from temporaryURL: URL) throws -> URL {
        let destinationDirectoryURL = try configuredDirectoryURL()
        guard destinationDirectoryURL.startAccessingSecurityScopedResource() else {
            throw ImageSaveError.directoryAccessFailed(destinationDirectoryURL)
        }
        defer {
            destinationDirectoryURL.stopAccessingSecurityScopedResource()
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destinationDirectoryURL.path, isDirectory: &isDirectory) else {
            throw ImageSaveError.configuredDirectoryNotFound(destinationDirectoryURL)
        }

        guard isDirectory.boolValue else {
            throw ImageSaveError.configuredPathIsNotDirectory(destinationDirectoryURL)
        }

        let destinationURL = destinationDirectoryURL.appendingPathComponent(temporaryURL.lastPathComponent)

        do {
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            throw ImageSaveError.moveToConfiguredDirectoryFailed(destinationURL)
        }

        guard fileManager.fileExists(atPath: destinationURL.path) else {
            throw ImageSaveError.moveToConfiguredDirectoryFailed(destinationURL)
        }

        return destinationURL
    }

    /// 删除指定位置的图像文件
    ///
    /// 如果文件不存在则不执行任何操作。
    ///
    /// - Parameter url: 要删除的文件 URL
    /// - Throws: `ImageSaveError.removeFailed` 如果删除操作失败
    func removeImage(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw ImageSaveError.removeFailed(url)
        }
    }

    private func writePNG(_ image: CGImage, to fileURL: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            fileURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageSaveError.destinationCreationFailed(fileURL)
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageSaveError.finalizeFailed(fileURL)
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw ImageSaveError.fileWriteFailed(fileURL)
        }
    }

    private func configuredDirectoryURL() throws -> URL {
        guard let bookmarkData = userDefaults.data(forKey: AppSettings.saveDirectoryBookmarkDataKey),
              !bookmarkData.isEmpty else {
            throw ImageSaveError.saveDirectoryNotConfigured
        }

        var isStale = false
        do {
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard !isStale else {
                throw ImageSaveError.directoryBookmarkStale
            }

            return resolvedURL
        } catch let error as ImageSaveError {
            throw error
        } catch {
            throw ImageSaveError.directoryBookmarkResolutionFailed
        }
    }

    private func temporaryDirectoryURL() -> URL {
        fileManager.temporaryDirectory
    }

    private func fileName(for date: Date) -> String {
        "Screenshot-\(dateFormatter.string(from: date)).png"
    }
}

/// 图像保存错误类型
///
/// 定义图像保存过程中可能发生的各种错误情况。
enum ImageSaveError: LocalizedError {
    /// 未配置保存目录
    case saveDirectoryNotConfigured
    /// 目录书签解析失败
    case directoryBookmarkResolutionFailed
    /// 目录书签已过期
    case directoryBookmarkStale
    /// 无法访问目录
    case directoryAccessFailed(URL)
    /// 配置的目录不存在
    case configuredDirectoryNotFound(URL)
    /// 配置的路径不是目录
    case configuredPathIsNotDirectory(URL)
    /// 无法创建 PNG 文件目标
    case destinationCreationFailed(URL)
    /// 无法完成 PNG 文件写入
    case finalizeFailed(URL)
    /// 文件写入失败
    case fileWriteFailed(URL)
    /// 无法移动文件到配置目录
    case moveToConfiguredDirectoryFailed(URL)
    /// 无法删除文件
    case removeFailed(URL)

    /// 错误的本地化描述
    var errorDescription: String? {
        switch self {
        case .saveDirectoryNotConfigured:
            return "Save directory not configured. Please choose a save directory in Settings first."
        case .directoryBookmarkResolutionFailed:
            return "Failed to resolve the configured save directory bookmark."
        case .directoryBookmarkStale:
            return "Configured save directory bookmark is stale. Please choose the save directory again."
        case let .directoryAccessFailed(url):
            return "Failed to access the configured save directory at \(url.path)."
        case let .configuredDirectoryNotFound(url):
            return "Configured save directory not found at \(url.path)."
        case let .configuredPathIsNotDirectory(url):
            return "Configured save path is not a directory at \(url.path)."
        case let .destinationCreationFailed(url):
            return "Failed to create PNG destination at \(url.path)."
        case let .finalizeFailed(url):
            return "Failed to finalize PNG file at \(url.path)."
        case let .fileWriteFailed(url):
            return "Failed to write PNG file at \(url.path)."
        case let .moveToConfiguredDirectoryFailed(url):
            return "Failed to move PNG file to configured directory at \(url.path)."
        case let .removeFailed(url):
            return "Failed to remove PNG file at \(url.path)."
        }
    }
}
