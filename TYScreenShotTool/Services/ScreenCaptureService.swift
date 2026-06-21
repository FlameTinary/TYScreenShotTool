//
//  ScreenCaptureService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/5.
//

import CoreGraphics
import CoreMedia
import Foundation
import AppKit
import ScreenCaptureKit

final class ScreenCaptureService {
    func captureScreenImages() async throws -> [CGDirectDisplayID: CGImage] {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw ScreenCaptureError.permissionRequired
        }

        let shareableContent = try await SCShareableContent.current
        var images: [CGDirectDisplayID: CGImage] = [:]

        for screen in NSScreen.screens {
            let displayID = try displayID(for: screen)
            guard let display = shareableContent.displays.first(where: { $0.displayID == displayID }) else {
                throw ScreenCaptureError.displayNotFound
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = Int(screen.frame.width * CGFloat(filter.pointPixelScale))
            configuration.height = Int(screen.frame.height * CGFloat(filter.pointPixelScale))
            configuration.showsCursor = false

            let image = try await captureImage(contentFilter: filter, configuration: configuration)
            images[displayID] = image
        }

        return images
    }

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

    func captureImageExcludingCurrentApplication(in rect: CGRect) async throws -> CGImage {
        guard rect.width > 1, rect.height > 1 else {
            throw ScreenCaptureError.invalidSelection
        }

        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw ScreenCaptureError.permissionRequired
        }

        return try await captureImageWithContentFilter(
            in: rect,
            excludingBundleIdentifier: Bundle.main.bundleIdentifier
        )
    }

    func captureImage(forWindowID windowID: CGWindowID) async throws -> CGImage {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw ScreenCaptureError.permissionRequired
        }

        let shareableContent = try await SCShareableContent.current
        guard let window = shareableContent.windows.first(where: { $0.windowID == windowID }) else {
            throw ScreenCaptureError.windowNotFound
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let contentInfo = SCShareableContent.info(for: filter)
        let contentRect = contentInfo.contentRect.integral

        guard contentRect.width > 1, contentRect.height > 1 else {
            throw ScreenCaptureError.invalidSelection
        }

        let configuration = SCStreamConfiguration()
        configuration.width = max(Int(contentRect.width * CGFloat(contentInfo.pointPixelScale)), 1)
        configuration.height = max(Int(contentRect.height * CGFloat(contentInfo.pointPixelScale)), 1)
        configuration.scalesToFit = false
        configuration.showsCursor = false

        return try await captureImage(contentFilter: filter, configuration: configuration)
    }

    func cropImage(_ image: CGImage, in screenFrame: CGRect, to screenRect: CGRect) throws -> CGImage {
        guard screenRect.width > 1, screenRect.height > 1 else {
            throw ScreenCaptureError.invalidSelection
        }
        let cropRect = CGRect(
            x: (screenRect.minX - screenFrame.minX) * (CGFloat(image.width) / screenFrame.width),
            y: (screenFrame.maxY - screenRect.maxY) * (CGFloat(image.height) / screenFrame.height),
            width: screenRect.width * (CGFloat(image.width) / screenFrame.width),
            height: screenRect.height * (CGFloat(image.height) / screenFrame.height)
        ).integral

        guard let croppedImage = image.cropping(to: cropRect) else {
            throw ScreenCaptureError.captureFailed
        }

        return croppedImage
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

    private func captureImageWithContentFilter(
        in rect: CGRect,
        excludingBundleIdentifier: String? = nil
    ) async throws -> CGImage {
        let shareableContent = try await SCShareableContent.current

        guard let screen = screen(containing: rect) else {
            throw ScreenCaptureError.displayNotFound
        }

        let displayID = try displayID(for: screen)
        guard let display = shareableContent.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenCaptureError.displayNotFound
        }

        let filter: SCContentFilter
        if let excludingBundleIdentifier,
           let application = shareableContent.applications.first(where: { $0.bundleIdentifier == excludingBundleIdentifier }) {
            filter = SCContentFilter(display: display, excludingApplications: [application], exceptingWindows: [])
        } else {
            filter = SCContentFilter(display: display, excludingWindows: [])
        }
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = CGRect(
            x: rect.origin.x - display.frame.origin.x,
            y: screen.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        configuration.width = Int(rect.width * CGFloat(filter.pointPixelScale))
        configuration.height = Int(rect.height * CGFloat(filter.pointPixelScale))
        configuration.showsCursor = false

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

    private func captureImage(
        contentFilter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: contentFilter, configuration: configuration) { image, error in
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
    case windowNotFound
}
