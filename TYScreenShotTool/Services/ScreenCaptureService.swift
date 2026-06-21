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

/// 屏幕捕获服务
///
/// 使用 ScreenCaptureKit 提供屏幕截图功能，支持全屏捕获、区域捕获和窗口捕获。
final class ScreenCaptureService {
    /// 捕获所有屏幕的图像
    ///
    /// 遍历所有连接的显示器，分别捕获每个屏幕的完整图像。
    ///
    /// - Returns: 以显示器 ID 为键、对应屏幕图像为值的字典
    /// - Throws: `ScreenCaptureError.permissionRequired` 如果缺少屏幕录制权限
    /// - Throws: `ScreenCaptureError.displayNotFound` 如果无法找到显示器
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

    /// 捕获指定矩形区域的屏幕图像
    ///
    /// 在 macOS 15.2+ 使用 `SCScreenshotManager.captureImage(in:)` 直接捕获，
    /// 在旧版本使用 ContentFilter 方式捕获。
    ///
    /// - Parameter rect: 要捕获的屏幕区域（使用屏幕坐标系）
    /// - Returns: 捕获的 CGImage
    /// - Throws: `ScreenCaptureError.invalidSelection` 如果区域尺寸无效
    /// - Throws: `ScreenCaptureError.permissionRequired` 如果缺少屏幕录制权限
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

    /// 捕获指定区域，排除当前应用程序窗口
    ///
    /// 用于截图时隐藏截图工具自身的窗口。
    ///
    /// - Parameter rect: 要捕获的屏幕区域
    /// - Returns: 捕获的 CGImage
    /// - Throws: `ScreenCaptureError.invalidSelection` 如果区域尺寸无效
    /// - Throws: `ScreenCaptureError.permissionRequired` 如果缺少屏幕录制权限
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

    /// 捕获指定窗口的图像
    ///
    /// 使用窗口 ID 独立捕获该窗口的内容，不包含其他窗口或桌面背景。
    ///
    /// - Parameter windowID: 要捕获的窗口 ID
    /// - Returns: 捕获的 CGImage
    /// - Throws: `ScreenCaptureError.permissionRequired` 如果缺少屏幕录制权限
    /// - Throws: `ScreenCaptureError.windowNotFound` 如果找不到指定窗口
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

    ///裁剪图像到指定屏幕区域
    ///
    /// 将全屏截图裁剪为指定的矩形区域，处理坐标系转换和像素缩放。
    ///
    /// - Parameters:
    ///   - image: 要裁剪的原始图像
    ///   - screenFrame: 屏幕的完整帧
    ///   - screenRect: 要裁剪的目标区域
    /// - Returns: 裁剪后的 CGImage
    /// - Throws: `ScreenCaptureError.invalidSelection` 如果裁剪区域无效
    /// - Throws: `ScreenCaptureError.captureFailed` 如果裁剪操作失败
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

/// 屏幕捕获错误类型
///
/// 定义屏幕捕获过程中可能发生的错误情况。
enum ScreenCaptureError: Error {
    /// 选区无效（尺寸太小）
    case invalidSelection
    /// 缺少屏幕录制权限
    case permissionRequired
    /// 无法找到显示器
    case displayNotFound
    /// 捕获操作失败
    case captureFailed
    /// 无法找到指定窗口
    case windowNotFound
}
