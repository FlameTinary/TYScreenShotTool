import XCTest
@testable import TShot

final class AnnotationToolTests: XCTestCase {

    // MARK: - All Cases

    func test_allCases_count() {
        XCTAssertEqual(AnnotationTool.allCases.count, 7)
    }

    func test_allCases_order() {
        let cases = AnnotationTool.allCases
        XCTAssertEqual(cases[0], .rectangle)
        XCTAssertEqual(cases[1], .ellipse)
        XCTAssertEqual(cases[2], .line)
        XCTAssertEqual(cases[3], .arrow)
        XCTAssertEqual(cases[4], .pen)
        XCTAssertEqual(cases[5], .mosaic)
        XCTAssertEqual(cases[6], .text)
    }

    // MARK: - Raw Identifier

    func test_rawIdentifier_rectangle() {
        XCTAssertEqual(AnnotationTool.rectangle.rawIdentifier, "rectangle")
    }

    func test_rawIdentifier_ellipse() {
        XCTAssertEqual(AnnotationTool.ellipse.rawIdentifier, "ellipse")
    }

    func test_rawIdentifier_line() {
        XCTAssertEqual(AnnotationTool.line.rawIdentifier, "line")
    }

    func test_rawIdentifier_arrow() {
        XCTAssertEqual(AnnotationTool.arrow.rawIdentifier, "arrow")
    }

    func test_rawIdentifier_pen() {
        XCTAssertEqual(AnnotationTool.pen.rawIdentifier, "pen")
    }

    func test_rawIdentifier_mosaic() {
        XCTAssertEqual(AnnotationTool.mosaic.rawIdentifier, "mosaic")
    }

    func test_rawIdentifier_text() {
        XCTAssertEqual(AnnotationTool.text.rawIdentifier, "text")
    }

    // MARK: - Symbol Name

    func test_symbolName_rectangle() {
        XCTAssertEqual(AnnotationTool.rectangle.symbolName, "rectangle")
    }

    func test_symbolName_ellipse() {
        XCTAssertEqual(AnnotationTool.ellipse.symbolName, "circle")
    }

    func test_symbolName_line() {
        XCTAssertEqual(AnnotationTool.line.symbolName, "line.diagonal")
    }

    func test_symbolName_arrow() {
        XCTAssertEqual(AnnotationTool.arrow.symbolName, "arrow.up.right")
    }

    func test_symbolName_pen() {
        XCTAssertEqual(AnnotationTool.pen.symbolName, "pencil.and.scribble")
    }

    func test_symbolName_mosaic() {
        XCTAssertEqual(AnnotationTool.mosaic.symbolName, "rectangle.pattern.checkered")
    }

    func test_symbolName_text() {
        XCTAssertEqual(AnnotationTool.text.symbolName, "square.and.pencil")
    }

    // MARK: - Equality

    func test_rectangle_equality() {
        XCTAssertEqual(AnnotationTool.rectangle, AnnotationTool.rectangle)
        XCTAssertNotEqual(AnnotationTool.rectangle, AnnotationTool.ellipse)
    }
}
