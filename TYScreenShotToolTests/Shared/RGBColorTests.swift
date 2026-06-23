import XCTest
@testable import TShot

final class RGBColorTests: XCTestCase {

    // MARK: - Preset Colors

    func test_presetColors_count() {
        XCTAssertEqual(RGBColor.presetColors.count, 8)
    }

    func test_presetColors_first_is_red() {
        let red = RGBColor.presetColors[0]
        XCTAssertEqual(red.red, 0.93, accuracy: 0.01)
        XCTAssertEqual(red.green, 0.24, accuracy: 0.01)
        XCTAssertEqual(red.blue, 0.21, accuracy: 0.01)
    }

    func test_presetColors_second_is_orange() {
        let orange = RGBColor.presetColors[1]
        XCTAssertEqual(orange.red, 1.00, accuracy: 0.01)
        XCTAssertEqual(orange.green, 0.58, accuracy: 0.01)
        XCTAssertEqual(orange.blue, 0.00, accuracy: 0.01)
    }

    func test_presetColors_third_is_yellow() {
        let yellow = RGBColor.presetColors[2]
        XCTAssertEqual(yellow.red, 1.00, accuracy: 0.01)
        XCTAssertEqual(yellow.green, 0.80, accuracy: 0.01)
        XCTAssertEqual(yellow.blue, 0.00, accuracy: 0.01)
    }

    func test_presetColors_fourth_is_green() {
        let green = RGBColor.presetColors[3]
        XCTAssertEqual(green.red, 0.20, accuracy: 0.01)
        XCTAssertEqual(green.green, 0.78, accuracy: 0.01)
        XCTAssertEqual(green.blue, 0.35, accuracy: 0.01)
    }

    func test_presetColors_fifth_is_blue() {
        let blue = RGBColor.presetColors[4]
        XCTAssertEqual(blue.red, 0.00, accuracy: 0.01)
        XCTAssertEqual(blue.green, 0.48, accuracy: 0.01)
        XCTAssertEqual(blue.blue, 1.00, accuracy: 0.01)
    }

    func test_presetColors_sixth_is_purple() {
        let purple = RGBColor.presetColors[5]
        XCTAssertEqual(purple.red, 0.69, accuracy: 0.01)
        XCTAssertEqual(purple.green, 0.32, accuracy: 0.01)
        XCTAssertEqual(purple.blue, 0.87, accuracy: 0.01)
    }

    func test_presetColors_seventh_is_white() {
        let white = RGBColor.presetColors[6]
        XCTAssertEqual(white.red, 1.00, accuracy: 0.01)
        XCTAssertEqual(white.green, 1.00, accuracy: 0.01)
        XCTAssertEqual(white.blue, 1.00, accuracy: 0.01)
    }

    func test_presetColors_eighth_is_black() {
        let black = RGBColor.presetColors[7]
        XCTAssertEqual(black.red, 0.00, accuracy: 0.01)
        XCTAssertEqual(black.green, 0.00, accuracy: 0.01)
        XCTAssertEqual(black.blue, 0.00, accuracy: 0.01)
    }

    // MARK: - Equatable

    func test_equal_colors_are_equal() {
        let a = RGBColor(red: 0.5, green: 0.5, blue: 0.5)
        let b = RGBColor(red: 0.5, green: 0.5, blue: 0.5)
        XCTAssertEqual(a, b)
    }

    func test_different_colors_are_not_equal() {
        let a = RGBColor(red: 0.5, green: 0.5, blue: 0.5)
        let b = RGBColor(red: 0.5, green: 0.5, blue: 0.6)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Color Conversion

    func test_toNSColor_returns_non_nil() {
        let color = RGBColor(red: 1.0, green: 0.0, blue: 0.0)
        let nsColor = color.toNSColor()
        XCTAssertNotNil(nsColor)
    }

    func test_toNSColor_has_correct_components() {
        let color = RGBColor(red: 0.5, green: 0.25, blue: 0.75)
        let nsColor = color.toNSColor()
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        XCTAssertEqual(red, 0.5, accuracy: 0.01)
        XCTAssertEqual(green, 0.25, accuracy: 0.01)
        XCTAssertEqual(blue, 0.75, accuracy: 0.01)
        XCTAssertEqual(alpha, 1.0, accuracy: 0.01)
    }

    func test_toCGColor_returns_non_nil() {
        let color = RGBColor(red: 0.0, green: 1.0, blue: 0.0)
        let cgColor = color.toCGColor()
        XCTAssertNotNil(cgColor)
    }

    func test_toCGColor_has_correct_components() {
        let color = RGBColor(red: 0.2, green: 0.4, blue: 0.6)
        let cgColor = color.toCGColor()
        guard let components = cgColor.components else {
            XCTFail("Expected components")
            return
        }
        XCTAssertEqual(components[0], 0.2, accuracy: 0.01)
        XCTAssertEqual(components[1], 0.4, accuracy: 0.01)
        XCTAssertEqual(components[2], 0.6, accuracy: 0.01)
    }
}
