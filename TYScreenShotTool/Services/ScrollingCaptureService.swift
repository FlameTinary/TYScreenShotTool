//
//  ScrollingCaptureService.swift
//  TYScreenShotTool
//
//  Created by Ethan on 2026/6/14.
//

import CoreGraphics
import Foundation

final class ScrollingCaptureService {
    func hasVisualChange(between lhs: CGImage, and rhs: CGImage) throws -> Bool {
        let lhsPixels = try ImagePixels(lhs)
        let rhsPixels = try ImagePixels(rhs)
        return transition(previous: lhsPixels, current: rhsPixels) != nil
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

            guard let transition = transition(previous: previous, current: current) else {
                continue
            }

            let cropRect = CGRect(
                x: 0,
                y: transition.overlapHeight,
                width: current.width,
                height: transition.segmentHeight
            )

            guard let croppedImage = normalizedFrames[index].cropping(to: cropRect) else {
                continue
            }

            segmentImages.append(croppedImage)
            segmentHeights.append(transition.segmentHeight)
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

    func buildCurrentPreviewImage(from frames: [CGImage]) throws -> CGImage {
        guard frames.isEmpty == false else {
            throw ScrollingCaptureError.noFrames
        }

        if frames.count == 1, let firstFrame = frames.first {
            return firstFrame
        }

        return try stitchVertically(frames)
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

    private func transition(previous: ImagePixels, current: ImagePixels) -> FrameTransition? {
        guard previous.width == current.width, previous.height == current.height else {
            return nil
        }

        let frameHeight = min(previous.height, current.height)
        let minimumShift = max(18, frameHeight / 20)
        let maximumShift = min(Int(Double(frameHeight) * 0.45), frameHeight - 1)

        guard maximumShift >= minimumShift else {
            return nil
        }

        let baselineDifference = averageDifference(
            previous: previous,
            current: current,
            shift: 0
        )
        let match = bestScrollMatch(
            previous: previous,
            current: current,
            minimumShift: minimumShift,
            maximumShift: maximumShift
        )

        guard let match else {
            return nil
        }

        let absoluteThreshold = 14
        let relativeThreshold = Int(Double(baselineDifference) * 0.45)
        let allowedScore = max(absoluteThreshold, relativeThreshold)

        guard match.score <= allowedScore else {
            return nil
        }

        let overlapHeight = refinedSeamRow(
            around: current.height - match.shift,
            in: current
        )
        let segmentHeight = current.height - overlapHeight

        guard overlapHeight > 0, segmentHeight > 0 else {
            return nil
        }

        return FrameTransition(
            overlapHeight: overlapHeight,
            segmentHeight: segmentHeight
        )
    }

    private func bestScrollMatch(
        previous: ImagePixels,
        current: ImagePixels,
        minimumShift: Int,
        maximumShift: Int
    ) -> ScrollMatch? {
        var bestMatch: ScrollMatch?

        for shift in stride(from: minimumShift, through: maximumShift, by: 2) {
            let score = averageDifference(
                previous: previous,
                current: current,
                shift: shift
            )

            guard score < Int.max else {
                continue
            }

            if let bestMatch, bestMatch.score <= score {
                continue
            }

            bestMatch = ScrollMatch(shift: shift, score: score)
        }

        return bestMatch
    }

    private func averageDifference(
        previous: ImagePixels,
        current: ImagePixels,
        shift: Int
    ) -> Int {
        let frameHeight = min(previous.height, current.height)
        let comparableHeight = frameHeight - shift

        guard comparableHeight > 0 else {
            return Int.max
        }

        let sampleRowCount = 20
        let xSampleCount = min(40, max(12, previous.width / 90))
        let rowStep = max(comparableHeight / sampleRowCount, 1)
        var testedRows = 0
        var totalDifference = 0

        var currentRow = 0
        while currentRow < comparableHeight {
            let previousRow = currentRow + shift
            let rowDifference = previous.rowDifference(
                comparedTo: current,
                previousRow: previousRow,
                currentRow: currentRow,
                xSampleCount: xSampleCount
            )

            totalDifference += rowDifference
            testedRows += 1
            currentRow += rowStep
        }

        guard testedRows > 0 else {
            return Int.max
        }

        return totalDifference / testedRows
    }

    private func refinedSeamRow(around proposedRow: Int, in pixels: ImagePixels) -> Int {
        let searchRadius = min(28, max(pixels.height / 18, 12))
        let minimumRow = max(6, proposedRow - searchRadius)
        let maximumRow = min(pixels.height - 6, proposedRow + searchRadius)

        guard minimumRow <= maximumRow else {
            return proposedRow
        }

        var bestRow = proposedRow
        var bestScore = Int.max

        for candidateRow in minimumRow...maximumRow {
            let activityScore = pixels.bandActivityScore(centeredAt: candidateRow, radius: 2)
            let distancePenalty = abs(candidateRow - proposedRow) * 6
            let candidateScore = activityScore + distancePenalty

            if candidateScore < bestScore {
                bestScore = candidateScore
                bestRow = candidateRow
            }
        }

        return bestRow
    }

    private struct ScrollMatch {
        let shift: Int
        let score: Int
    }

    private struct FrameTransition {
        let overlapHeight: Int
        let segmentHeight: Int
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

    func bandActivityScore(centeredAt row: Int, radius: Int) -> Int {
        let lowerBound = max(0, row - radius)
        let upperBound = min(height - 1, row + radius)
        var totalScore = 0
        var sampledRows = 0

        for currentRow in lowerBound...upperBound {
            totalScore += rowActivityScore(at: currentRow)
            sampledRows += 1
        }

        guard sampledRows > 0 else {
            return Int.max
        }

        return totalScore / sampledRows
    }

    private func rowActivityScore(at row: Int) -> Int {
        guard row >= 0, row < height else {
            return Int.max
        }

        let step = max(width / 48, 1)
        var previousLuminance: Int?
        var totalDifference = 0
        var samples = 0
        var x = 0

        while x < width {
            let index = row * bytesPerRow + (x * 4)
            let luminance = (
                Int(data[index]) * 299
                + Int(data[index + 1]) * 587
                + Int(data[index + 2]) * 114
            ) / 1000

            if let previousLuminance {
                totalDifference += abs(luminance - previousLuminance)
                samples += 1
            }

            previousLuminance = luminance
            x += step
        }

        guard samples > 0 else {
            return Int.max
        }

        return totalDifference / samples
    }
}
