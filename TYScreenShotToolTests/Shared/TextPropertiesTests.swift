import XCTest
@testable import TShot

final class TextPropertiesTests: XCTestCase {

    func test_default_matches_legacy_text_style() {
        let properties = TextProperties.default

        XCTAssertEqual(properties.fontSize, 22)
        XCTAssertEqual(properties.opacity, 1.0, accuracy: 0.001)
        XCTAssertEqual(
            properties.color,
            RGBColor(red: 0.93, green: 0.24, blue: 0.21)
        )
    }

    func test_custom_properties_are_equatable() {
        let properties = TextProperties(
            fontSize: 28,
            opacity: 0.65,
            color: RGBColor(red: 0, green: 0.48, blue: 1)
        )

        XCTAssertEqual(
            properties,
            TextProperties(
                fontSize: 28,
                opacity: 0.65,
                color: RGBColor(red: 0, green: 0.48, blue: 1)
            )
        )
    }
}
