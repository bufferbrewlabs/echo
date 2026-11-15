@testable import Echo
import XCTest

final class PopupKeyTests: XCTestCase {
    private func action(_ keyCode: UInt16, _ characters: String? = nil, command: Bool = false,
                        editingSearch: Bool = true, composing: Bool = false) -> StatusBarController.PopupKeyAction {
        StatusBarController.popupKeyAction(keyCode: keyCode, characters: characters, command: command,
                                           editingSearch: editingSearch, composingText: composing)
    }

    func testArrowsMoveSelectionFromTheSearchField() {
        XCTAssertEqual(action(125), .moveSelection(1))
        XCTAssertEqual(action(126), .moveSelection(-1))
    }

    func testArrowsKeepNormalFocusBehaviourOutsideTheSearchField() {
        XCTAssertEqual(action(125, editingSearch: false), .passThrough)
        XCTAssertEqual(action(126, editingSearch: false), .passThrough)
    }

    func testReturnAndKeypadEnterPasteFromAnywhere() {
        XCTAssertEqual(action(36), .paste)
        XCTAssertEqual(action(76), .paste)
        XCTAssertEqual(action(36, editingSearch: false), .paste)
    }

    func testEscapeCloses() {
        XCTAssertEqual(action(53), .close)
    }

    func testCommandShortcuts() {
        XCTAssertEqual(action(3, "f", command: true), .focusSearch)
        XCTAssertEqual(action(43, ",", command: true), .openSettings)
        XCTAssertEqual(action(0, "a", command: true), .passThrough, "⌘A must still select all in search")
        XCTAssertEqual(action(36, nil, command: true), .passThrough)
    }

    func testComposedInputIsCommittedBeforeActing() {
        XCTAssertEqual(action(36, composing: true), .passThrough)
        XCTAssertEqual(action(125, composing: true), .passThrough)
        XCTAssertEqual(action(53, composing: true), .passThrough)
    }

    func testTypingReachesTheSearchField() {
        XCTAssertEqual(action(0, "a"), .passThrough)
        XCTAssertEqual(action(51), .passThrough) // Delete
    }
}
