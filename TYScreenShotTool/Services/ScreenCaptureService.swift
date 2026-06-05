//
//  ScreenCaptureService.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/5.
//

import CoreGraphics
import CoreMedia
import Foundation
import ScreenCaptureKit

final class ScreenCaptureService {
    func captureImage(in rect: CGRect) async throws -> CGImage {
        guard rect.width > 1, rect.height > 1 else {
            throw ScreenCaptureError.invalidSelection
        }

        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw ScreenCaptureError.permissionRequired
        }

        if #available(macOS 15.2, *) {
            return try await captureImageInRect(rect)
        }

        return try await captureImageWithContentFilter(in: rect)
    }

    @available(macOS 15.2, *)
    private func captureImageInRect(_ rect: CGRect) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(in: rect) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let image else {
                    continuation.resume(throwing: ScreenCaptureError.captureFailed)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    private func captureImageWithContentFilter(in rect: CGRect) async throws -> CGImage {
        let shareableContent = try await SCShareableContent.current

        guard let display = shareableContent.displays.first(where: { $0.frame.contains(rect) }) else {
            throw ScreenCaptureError.displayNotFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = CGRect(
            x: rect.origin.x - display.frame.origin.x,
            y: rect.origin.y - display.frame.origin.y,
            width: rect.width,
            height: rect.height
        )
        configuration.width = Int(rect.width * CGFloat(filter.pointPixelScale))
        configuration.height = Int(rect.height * CGFloat(filter.pointPixelScale))

        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let image else {
                    continuation.resume(throwing: ScreenCaptureError.captureFailed)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }
}

enum ScreenCaptureError: Error {
    case invalidSelection
    case permissionRequired
    case displayNotFound
    case captureFailed
}
