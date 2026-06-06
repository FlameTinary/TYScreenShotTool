//
//  OCRService.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/6.
//

import CoreGraphics
import Foundation
import Vision

final class OCRService {
    func recognizeText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw OCRError.requestFailed(error.localizedDescription)
        }

        guard let observations = request.results, !observations.isEmpty else {
            throw OCRError.noTextRecognized
        }

        let lines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            throw OCRError.emptyText
        }

        return lines.joined(separator: "\n")
    }
}

enum OCRError: LocalizedError {
    case requestFailed(String)
    case noTextRecognized
    case emptyText

    var errorDescription: String? {
        switch self {
        case let .requestFailed(reason):
            return "Failed to perform OCR request: \(reason)"
        case .noTextRecognized:
            return "No text recognized from screenshot."
        case .emptyText:
            return "Recognized text is empty."
        }
    }
}
