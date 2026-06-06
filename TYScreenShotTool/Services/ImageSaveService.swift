//
//  ImageSaveService.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/5.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

final class ImageSaveService {
    private let fileManager: FileManager
    private let dateFormatter: DateFormatter

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss-SSS"
        self.dateFormatter = formatter
    }

    func saveTemporaryPNG(_ image: CGImage) throws -> URL {
        let temporaryURL = temporaryDirectoryURL().appendingPathComponent(fileName(for: Date()))
        try writePNG(image, to: temporaryURL)
        return temporaryURL
    }

    func moveImageToConfiguredDirectory(from temporaryURL: URL) throws -> URL {
        let destinationDirectoryURL = try configuredDirectoryURL()
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

    private func desktopDirectoryURL() throws -> URL {
        guard let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            throw ImageSaveError.desktopDirectoryUnavailable
        }

        return desktopURL
    }

    private func configuredDirectoryURL() throws -> URL {
        guard let configuredPath = UserDefaults.standard.string(forKey: AppSettings.saveDirectoryPathKey),
              !configuredPath.isEmpty else {
            return try desktopDirectoryURL()
        }

        let configuredURL = URL(fileURLWithPath: configuredPath, isDirectory: true)
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: configuredURL.path, isDirectory: &isDirectory) else {
            throw ImageSaveError.configuredDirectoryNotFound(configuredURL)
        }

        guard isDirectory.boolValue else {
            throw ImageSaveError.configuredPathIsNotDirectory(configuredURL)
        }

        return configuredURL
    }

    private func temporaryDirectoryURL() -> URL {
        fileManager.temporaryDirectory
    }

    private func fileName(for date: Date) -> String {
        "Screenshot-\(dateFormatter.string(from: date)).png"
    }
}

enum ImageSaveError: LocalizedError {
    case desktopDirectoryUnavailable
    case configuredDirectoryNotFound(URL)
    case configuredPathIsNotDirectory(URL)
    case destinationCreationFailed(URL)
    case finalizeFailed(URL)
    case fileWriteFailed(URL)
    case moveToConfiguredDirectoryFailed(URL)
    case removeFailed(URL)

    var errorDescription: String? {
        switch self {
        case .desktopDirectoryUnavailable:
            return "Desktop directory unavailable."
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
