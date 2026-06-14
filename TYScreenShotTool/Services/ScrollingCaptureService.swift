//
//  ScrollingCaptureService.swift
//  TYScreenShotTool
//
//  Created by Sheldon on 2026/6/14.
//

import CoreGraphics
import Foundation

final class ScrollingCaptureService {
    func hasVisualChange(between lhs: CGImage, and rhs: CGImage) throws -> Bool {
        let lhsPixels = try ImagePixels(lhs)
        let rhsPixels = try ImagePixels(rhs)
        return lhsPixels.isIdentical(to: rhsPixels) == false
    }

    func stitchVertically(_ frames: [CGImage]) throws -> CGImage {
        guard let firstFrame = frames.first else {
            throw ScrollingCaptureError.noFrames
        }

        guard frames.count > 1 else {
            return firstFrame
        }

        let normalizedFrames = try normalizeFrames(frames)
        let pixelFrames = try normalizedFrames.map(ImagePixels.init)
        var segmentImages: [CGImage] = [normalizedFrames[0]]
        var segmentHeights: [Int] = [normalizedFrames[0].height]
        var appendedSegmentCount = 0

        for index in 1..<normalizedFrames.count {
            let previous = pixelFrames[index - 1]
            let current = pixelFrames[index]

            if previous.isIdentical(to: current) {
                continue
            }

            let overlapHeight = bestOverlapHeight(previous: previous, current: current)
            let segmentHeight = current.height - overlapHeight

            guard segmentHeight > 0 else {
                continue
            }

            let cropRect = CGRect(
                x: 0,
                y: overlapHeight,
                width: current.width,
                height: segmentHeight
            )

            guard let croppedImage = normalizedFrames[index].cropping(to: cropRect) else {
                continue
            }

            segmentImages.append(croppedImage)
            segmentHeights.append(segmentHeight)
            appendedSegmentCount += 1
        }

        guard appendedSegmentCount > 0 else {
            throw ScrollingCaptureError.noUsableFrames
        }

        return try renderStitchedImage(
            segmentImages: segmentImages,
            width: normalizedFrames[0].width,
            segmentHeights: segmentHeights
        )
    }

    private func normalizeFrames(_ frames: [CGImage]) throws -> [CGImage] {
        guard let minimumWidth = frames.map(\.width).min(), let minimumHeight = frames.map(\.height).min() else {
            throw ScrollingCaptureError.noFrames
        }

        return try frames.map { frame in
            if frame.width == minimumWidth, frame.height == minimumHeight {
                return frame
            }

            let cropRect = CGRect(
                x: 0,
                y: 0,
                width: minimumWidth,
                height: minimumHeight
            )

            guard let croppedImage = frame.cropping(to: cropRect) else {
                throw ScrollingCaptureError.cropFailed
            }

            return croppedImage
        }
    }

    private func renderStitchedImage(
        segmentImages: [CGImage],
        width: Int,
        segmentHeights: [Int]
    ) throws -> CGImage {
        let totalHeight = segmentHeights.reduce(0, +)

        guard
            let colorSpace = segmentImages.first?.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: width,
                height: totalHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw ScrollingCaptureError.contextCreationFailed
        }

        context.interpolationQuality = .high

        var currentY = totalHeight
        for (image, height) in zip(segmentImages, segmentHeights) {
            currentY -= height
            context.draw(
                image,
                in: CGRect(x: 0, y: currentY, width: width, height: height)
            )
        }

        guard let stitchedImage = context.makeImage() else {
            throw ScrollingCaptureError.imageCreationFailed
        }

        return stitchedImage
    }

    private func bestOverlapHeight(previous: ImagePixels, current: ImagePixels) -> Int {
        let frameHeight = min(previous.height, current.height)
        let minimumOverlap = max(24, frameHeight / 10)
        let maximumOverlap = min(Int(Double(frameHeight) * 0.78), frameHeight - 1)

        guard maximumOverlap >= minimumOverlap else {
            return fallbackOverlapHeight(for: current.height)
        }

        let sampleRowCount = 20
        let xSampleCount = min(40, max(12, previous.width / 90))
        var bestOverlap = fallbackOverlapHeight(for: current.height)
        var bestScore = Int.max

        for overlap in stride(from: maximumOverlap, through: minimumOverlap, by: -1) {
            let rowStep = max(overlap / sampleRowCount, 1)
            var testedRows = 0
            var totalDifference = 0

            var rowOffset = 0
            while rowOffset < overlap {
                let previousRow = previous.height - overlap + rowOffset
                let currentRow = rowOffset

                let rowDifference = previous.rowDifference(
                    comparedTo: current,
                    previousRow: previousRow,
                    currentRow: currentRow,
                    xSampleCount: xSampleCount
                )

                totalDifference += rowDifference
                testedRows += 1
                rowOffset += rowStep
            }

            guard testedRows > 0 else {
                continue
            }

            let averageDifference = totalDifference / testedRows
            let overlapPenalty = Int(Double(overlap) * 0.08)
            let adjustedScore = averageDifference + overlapPenalty

            if adjustedScore < bestScore {
                bestScore = adjustedScore
                bestOverlap = overlap
            }
        }

        return bestOverlap
    }

    private func fallbackOverlapHeight(for frameHeight: Int) -> Int {
        let candidate = Int(Double(frameHeight) * 0.60)
        return min(max(candidate, 1), frameHeight - 1)
    }
}

enum ScrollingCaptureError: LocalizedError {
    case noFrames
    case noUsableFrames
    case frameSizeMismatch
    case noScrollChange
    case overlapNotFound
    case invalidOverlap
    case cropFailed
    case contextCreationFailed
    case imageCreationFailed

    var errorDescription: String? {
        switch self {
        case .noFrames:
            return "No frames available for scrolling capture."
        case .noUsableFrames:
            return "No usable scrolling capture frames were produced."
        case .frameSizeMismatch:
            return "Scrolling capture frames have mismatched sizes."
        case .noScrollChange:
            return "No scroll change detected. Please scroll the target content before appending the next frame."
        case .overlapNotFound:
            return "Failed to match overlapping content between scrolling capture frames."
        case .invalidOverlap:
            return "Scrolling capture overlap is invalid."
        case .cropFailed:
            return "Failed to crop scrolling capture frame."
        case .contextCreationFailed:
            return "Failed to create scrolling capture render context."
        case .imageCreationFailed:
            return "Failed to create scrolling capture image."
        }
    }
}

private nonisolated struct ImagePixels {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let data: [UInt8]

    init(_ image: CGImage) throws {
        width = image.width
        height = image.height
        bytesPerRow = width * 4

        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: &buffer,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw ScrollingCaptureError.contextCreationFailed
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        data = buffer
    }

    func isIdentical(to other: ImagePixels) -> Bool {
        width == other.width && height == other.height && data == other.data
    }

    func rowDifference(
        comparedTo other: ImagePixels,
        previousRow: Int,
        currentRow: Int,
        xSampleCount: Int
    ) -> Int {
        guard previousRow >= 0, previousRow < height, currentRow >= 0, currentRow < other.height else {
            return Int.max
        }

        let sampleCount = max(xSampleCount, 1)
        let step = max(width / sampleCount, 1)
        var totalDifference = 0
        var comparedSamples = 0

        var x = 0
        while x < width {
            let lhsIndex = previousRow * bytesPerRow + (x * 4)
            let rhsIndex = currentRow * other.bytesPerRow + (x * 4)

            totalDifference += abs(Int(data[lhsIndex]) - Int(other.data[rhsIndex]))
            totalDifference += abs(Int(data[lhsIndex + 1]) - Int(other.data[rhsIndex + 1]))
            totalDifference += abs(Int(data[lhsIndex + 2]) - Int(other.data[rhsIndex + 2]))

            comparedSamples += 3
            x += step
        }

        guard comparedSamples > 0 else {
            return Int.max
        }

        return totalDifference / comparedSamples
    }
}
