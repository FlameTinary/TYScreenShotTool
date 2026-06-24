import XCTest
@testable import TShot

final class CaptureAnnotationTextTests: XCTestCase {

    func test_text_bounds_use_text_properties_font_size() {
        let properties = TextProperties(
            fontSize: 30,
            opacity: 0.8,
            color: RGBColor(red: 1, green: 0.8, blue: 0)
        )
        let annotation = CaptureAnnotation.text(
            value: "Hi",
            origin: CGPoint(x: 40, y: 60),
            properties: properties
        )

        let bounds = annotation.bounds

        XCTAssertEqual(bounds.origin.x, 40, accuracy: 0.001)
        XCTAssertEqual(bounds.origin.y, 60, accuracy: 0.001)
        XCTAssertEqual(bounds.width, 36, accuracy: 0.001)
        XCTAssertEqual(bounds.height, 42, accuracy: 0.001)
    }

    func test_text_annotation_keeps_text_properties() {
        let properties = TextProperties(
            fontSize: 26,
            opacity: 0.55,
            color: RGBColor(red: 0.2, green: 0.78, blue: 0.35)
        )
        let annotation = CaptureAnnotation.text(
            value: "Hello",
            origin: CGPoint(x: 12, y: 24),
            properties: properties
        )

        guard case let .text(_, _, storedProperties) = annotation else {
            return XCTFail("Expected text annotation")
        }

        XCTAssertEqual(storedProperties, properties)
    }
}
