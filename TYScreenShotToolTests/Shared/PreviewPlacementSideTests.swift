import XCTest
@testable import TShot

final class PreviewPlacementSideTests: XCTestCase {

    func test_left_opposite_is_right() {
        XCTAssertEqual(PreviewPlacementSide.left.opposite, .right)
    }

    func test_right_opposite_is_left() {
        XCTAssertEqual(PreviewPlacementSide.right.opposite, .left)
    }
}
