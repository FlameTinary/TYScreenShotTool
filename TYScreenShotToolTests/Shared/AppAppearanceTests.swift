import XCTest
@testable import TShot

final class AppAppearanceTests: XCTestCase {

    func test_storageValue_system() {
        XCTAssertEqual(AppAppearance.system.storageValue, "system")
    }

    func test_storageValue_light() {
        XCTAssertEqual(AppAppearance.light.storageValue, "light")
    }

    func test_storageValue_dark() {
        XCTAssertEqual(AppAppearance.dark.storageValue, "dark")
    }

    func test_nsAppearance_system_is_nil() {
        XCTAssertNil(AppAppearance.system.nsAppearance)
    }

    func test_nsAppearance_light_is_aqua() {
        let appearance = AppAppearance.light.nsAppearance
        XCTAssertEqual(appearance?.name, NSAppearance.Name.aqua)
    }

    func test_nsAppearance_dark_is_darkAqua() {
        let appearance = AppAppearance.dark.nsAppearance
        XCTAssertEqual(appearance?.name, NSAppearance.Name.darkAqua)
    }

    func test_allCases_count() {
        XCTAssertEqual(AppAppearance.allCases.count, 3)
    }

    func test_allCases_order() {
        let cases = AppAppearance.allCases
        XCTAssertEqual(cases[0], .system)
        XCTAssertEqual(cases[1], .light)
        XCTAssertEqual(cases[2], .dark)
    }
}
