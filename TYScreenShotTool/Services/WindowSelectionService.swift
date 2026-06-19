//
//  WindowSelectionService.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/19.
//

import AppKit
import CoreGraphics

struct WindowSelectionCandidate {
    let frame: CGRect
    let ownerName: String
    let windowID: CGWindowID
}

final class WindowSelectionService {
    func candidateWindow(at screenPoint: CGPoint) -> WindowSelectionCandidate? {
        guard let screen = screenContaining(screenPoint) else {
            return nil
        }

        let cgPoint = cgPoint(from: screenPoint, on: screen)

        guard let windowInfos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for windowInfo in windowInfos {
            guard let candidate = candidate(from: windowInfo, on: screen), candidate.cgFrame.contains(cgPoint) else {
                continue
            }

            return WindowSelectionCandidate(
                frame: candidate.frame,
                ownerName: candidate.ownerName,
                windowID: candidate.windowID
            )
        }

        return nil
    }
}

private extension WindowSelectionService {
    struct ResolvedWindowCandidate {
        let frame: CGRect
        let cgFrame: CGRect
        let ownerName: String
        let windowID: CGWindowID
    }

    func candidate(from windowInfo: [String: Any], on screen: NSScreen) -> ResolvedWindowCandidate? {
        guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
              ownerPID != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }

        guard let cgBounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let cgFrame = CGRect(dictionaryRepresentation: cgBounds as CFDictionary),
              cgFrame.width > 40,
              cgFrame.height > 40 else {
            return nil
        }

        guard let windowNumber = windowInfo[kCGWindowNumber as String] as? NSNumber else {
            return nil
        }

        let ownerName = (windowInfo[kCGWindowOwnerName as String] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard ownerName.isEmpty == false else {
            return nil
        }

        let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
        guard layer == 0 else {
            return nil
        }

        let alpha = windowInfo[kCGWindowAlpha as String] as? Double ?? 1
        guard alpha > 0 else {
            return nil
        }

        guard let frame = appKitScreenFrame(from: cgFrame, on: screen),
              frameContainedInScreen(frame, screen: screen),
              frame.width > 40,
              frame.height > 40 else {
            return nil
        }

        return ResolvedWindowCandidate(
            frame: frame,
            cgFrame: cgFrame,
            ownerName: ownerName,
            windowID: CGWindowID(windowNumber.uint32Value)
        )
    }

    func appKitScreenFrame(from cgFrame: CGRect, on screen: NSScreen) -> CGRect? {
        let convertedY = screen.frame.maxY - cgFrame.origin.y - cgFrame.height

        let frame = CGRect(
            x: cgFrame.origin.x,
            y: convertedY,
            width: cgFrame.width,
            height: cgFrame.height
        )

        return frame.isNull ? nil : frame
    }

    func frameContainedInScreen(_ frame: CGRect, screen: NSScreen) -> Bool {
        screen.frame.minX <= frame.minX &&
            screen.frame.maxX >= frame.maxX &&
            screen.frame.minY <= frame.minY &&
            screen.frame.maxY >= frame.maxY
    }

    func screenContaining(_ point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    func cgPoint(from point: CGPoint, on screen: NSScreen) -> CGPoint {
        CGPoint(x: point.x, y: screen.frame.maxY - point.y)
    }
}
