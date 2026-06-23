import AppKit
import XCTest
@testable import TShot

@MainActor
final class ScrollingCapturePreviewContentViewTests: XCTestCase {

    func test_imageView_usesLowLayoutPriorities_toAvoidExpandingParent() throws {
        let view = ScrollingCapturePreviewContentView(frame: .zero)
        let imageView = try XCTUnwrap(findImageView(in: view))

        XCTAssertFalse(imageView.translatesAutoresizingMaskIntoConstraints)
        XCTAssertEqual(imageView.contentHuggingPriority(for: .horizontal), .defaultLow)
        XCTAssertEqual(imageView.contentHuggingPriority(for: .vertical), .defaultLow)
        XCTAssertEqual(imageView.contentCompressionResistancePriority(for: .horizontal), .defaultLow)
        XCTAssertEqual(imageView.contentCompressionResistancePriority(for: .vertical), .defaultLow)
    }

    private func findImageView(in view: NSView) -> NSImageView? {
        if let imageView = view as? NSImageView {
            return imageView
        }

        for subview in view.subviews {
            if let imageView = findImageView(in: subview) {
                return imageView
            }
        }

        return nil
    }
}
