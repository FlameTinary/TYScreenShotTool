import XCTest
@testable import TShot

final class CaptureStateTests: XCTestCase {

    func test_displayName_idle() {
        XCTAssertEqual(CaptureState.idle.displayName, "Idle")
    }

    func test_displayName_overlayPresented() {
        XCTAssertEqual(CaptureState.overlayPresented.displayName, "OverlayPresented")
    }

    func test_displayName_dragging() {
        XCTAssertEqual(CaptureState.dragging.displayName, "Dragging")
    }

    func test_displayName_selectionCompleted() {
        XCTAssertEqual(CaptureState.selectionCompleted.displayName, "SelectionCompleted")
    }
}
