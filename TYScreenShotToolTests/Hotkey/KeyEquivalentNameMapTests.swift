import Carbon
import XCTest
@testable import TShot

final class KeyEquivalentNameMapTests: XCTestCase {

    // MARK: - Known Key Mappings

    func test_returns_displayName_for_ANSI_A() {
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_A)), "A")
    }

    func test_returns_displayName_for_ANSI_Z() {
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_Z)), "Z")
    }

    func test_returns_displayName_for_ANSI_0() {
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_0)), "0")
    }

    func test_returns_displayName_for_ANSI_9() {
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_9)), "9")
    }

    func test_returns_displayName_for_all_letter_keys() {
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_A)), "A")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_B)), "B")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_C)), "C")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_D)), "D")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_E)), "E")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_F)), "F")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_G)), "G")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_H)), "H")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_I)), "I")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_J)), "J")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_K)), "K")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_L)), "L")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_M)), "M")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_N)), "N")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_O)), "O")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_P)), "P")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_Q)), "Q")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_R)), "R")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_S)), "S")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_T)), "T")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_U)), "U")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_V)), "V")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_W)), "W")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_X)), "X")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_Y)), "Y")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_Z)), "Z")
    }

    func test_returns_displayName_for_all_digit_keys() {
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_0)), "0")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_1)), "1")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_2)), "2")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_3)), "3")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_4)), "4")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_5)), "5")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_6)), "6")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_7)), "7")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_8)), "8")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_ANSI_9)), "9")
    }

    // MARK: - Function Keys

    func test_returns_displayName_for_F1() {
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_F1)), "F1")
    }

    func test_returns_displayName_for_F12() {
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_F12)), "F12")
    }

    func test_returns_displayName_for_all_F_keys() {
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_F1)), "F1")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_F2)), "F2")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_F3)), "F3")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_F4)), "F4")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_F5)), "F5")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_F6)), "F6")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_F7)), "F7")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_F8)), "F8")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_F9)), "F9")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_F10)), "F10")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_F11)), "F11")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_F12)), "F12")
    }

    // MARK: - Arrow Keys

    func test_returns_displayName_for_arrow_keys() {
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_UpArrow)), "↑")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_DownArrow)), "↓")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_LeftArrow)), "←")
        XCTAssertEqual(KeyEquivalentNameMap.displayName(for: UInt32(kVK_RightArrow)), "→")
    }

    // MARK: - Unsupported Key Codes

    func test_returns_nil_for_unsupported_keyCode() {
        XCTAssertNil(KeyEquivalentNameMap.displayName(for: 0xFFFF))
        XCTAssertNil(KeyEquivalentNameMap.displayName(for: 0xDEADBEEF))
        XCTAssertNil(KeyEquivalentNameMap.displayName(for: UInt32.max))
    }

    func test_returns_nil_for_return_key() {
        // kVK_Return is not in the map — not a valid hotkey key
        XCTAssertNil(KeyEquivalentNameMap.displayName(for: UInt32(kVK_Return)))
    }

    func test_returns_nil_for_space_key() {
        XCTAssertNil(KeyEquivalentNameMap.displayName(for: UInt32(kVK_Space)))
    }

    func test_returns_nil_for_delete_key() {
        XCTAssertNil(KeyEquivalentNameMap.displayName(for: UInt32(kVK_Delete)))
    }

    func test_returns_nil_for_escape_key() {
        XCTAssertNil(KeyEquivalentNameMap.displayName(for: UInt32(kVK_Escape)))
    }

    func test_returns_nil_for_tab_key() {
        XCTAssertNil(KeyEquivalentNameMap.displayName(for: UInt32(kVK_Tab)))
    }
}
