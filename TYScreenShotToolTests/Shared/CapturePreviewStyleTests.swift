import XCTest
@testable import TShot

final class CapturePreviewStyleTests: XCTestCase {

    func test_default_cornerRadius_is_zero() {
        XCTAssertEqual(CapturePreviewStyle.default.cornerRadius, 0)
    }

    func test_default_showsShadow_is_false() {
        XCTAssertFalse(CapturePreviewStyle.default.showsShadow)
    }

    func test_custom_style() {
        let style = CapturePreviewStyle(cornerRadius: 12, showsShadow: true)
        XCTAssertEqual(style.cornerRadius, 12)
        XCTAssertTrue(style.showsShadow)
    }
}
