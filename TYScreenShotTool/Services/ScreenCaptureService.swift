//
//  ScreenCaptureService.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/5.
//

import CoreGraphics
import CoreMedia
import Foundation
import AppKit
import ScreenCaptureKit

final class ScreenCaptureService {
    func captureImage(in rect: CGRect) async throws -> CGImage {
        guard rect.width > 1, rect.height > 1 else {
            throw ScreenCaptureError.invalidSelection
        }

        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw ScreenCaptureError.permissionRequired
        }

        let captureRect = try screenCaptureRect(from: rect)

        if #available(macOS 15.2, *) {
            return try await captureImageInRect(captureRect)
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

        guard let screen = screen(containing: rect) else {
            throw ScreenCaptureError.displayNotFound
        }

        let displayID = try displayID(for: screen)
        guard let display = shareableContent.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenCaptureError.displayNotFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = CGRect(
            x: rect.origin.x - display.frame.origin.x,
            y: screen.frame.maxY - rect.maxY,
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

    private func screenCaptureRect(from rect: CGRect) throws -> CGRect {
        guard let desktopMaxY = NSScreen.screens.map(\.frame.maxY).max() else {
            throw ScreenCaptureError.displayNotFound
        }

        return CGRect(
            x: rect.origin.x,
            y: desktopMaxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func screen(containing rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(CGPoint(x: rect.midX, y: rect.midY)) }
    }

    private func displayID(for screen: NSScreen) throws -> CGDirectDisplayID {
        guard
            let value = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            throw ScreenCaptureError.displayNotFound
        }

        return CGDirectDisplayID(value.uint32Value)
    }
}

enum ScreenCaptureError: Error {
    case invalidSelection
    case permissionRequired
    case displayNotFound
    case captureFailed
}
