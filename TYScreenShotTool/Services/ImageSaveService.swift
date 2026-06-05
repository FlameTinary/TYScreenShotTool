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

    func savePNG(_ image: CGImage) throws -> URL {
        let desktopURL = try desktopDirectoryURL()
        let fileURL = desktopURL.appendingPathComponent(fileName(for: Date()))

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

        return fileURL
    }

    private func desktopDirectoryURL() throws -> URL {
        guard let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            throw ImageSaveError.desktopDirectoryUnavailable
        }

        return desktopURL
    }

    private func fileName(for date: Date) -> String {
        "Screenshot-\(dateFormatter.string(from: date)).png"
    }
}

enum ImageSaveError: LocalizedError {
    case desktopDirectoryUnavailable
    case destinationCreationFailed(URL)
    case finalizeFailed(URL)
    case fileWriteFailed(URL)

    var errorDescription: String? {
        switch self {
        case .desktopDirectoryUnavailable:
            return "Desktop directory unavailable."
        case let .destinationCreationFailed(url):
            return "Failed to create PNG destination at \(url.path)."
        case let .finalizeFailed(url):
            return "Failed to finalize PNG file at \(url.path)."
        case let .fileWriteFailed(url):
            return "Failed to write PNG file at \(url.path)."
        }
    }
}
