@testable import Echo
import XCTest

final class HistoryViewModelTests: XCTestCase {
    private let clips = [
        ClipboardItem(kind: .text, text: "Design notes"),
        ClipboardItem(kind: .image, imageFileName: "example.png"),
        ClipboardItem(kind: .text, text: "Release checklist")
    ]

    func testFiltersCombineWithSearchAndPreserveOrder() {
        let model = HistoryViewModel()
        XCTAssertEqual(model.filteredItems(from: clips), clips)
        model.filter = .text
        XCTAssertEqual(model.filteredItems(from: clips), [clips[0], clips[2]])
        model.searchText = "  DESIGN  "
        XCTAssertEqual(model.filteredItems(from: clips), [clips[0]])
        model.filter = .images
        XCTAssertTrue(model.filteredItems(from: clips).isEmpty)
        model.searchText = "image"
        XCTAssertEqual(model.filteredItems(from: clips), [clips[1]])
    }

    func testChangingFilterAndSearchResetsSelection() {
        let model = HistoryViewModel()
        model.selectedIndex = 2
        model.filter = .images
        XCTAssertEqual(model.selectedIndex, 0)
        model.selectedIndex = 1
        model.searchText = "missing"
        XCTAssertEqual(model.selectedIndex, 0)
    }

    func testSelectionClampsWhenResultsShrinkOrDisappear() {
        let model = HistoryViewModel()
        model.moveSelection(by: 20, count: clips.count)
        XCTAssertEqual(model.selectedIndex, 2)
        model.moveSelection(by: -20, count: clips.count)
        XCTAssertEqual(model.selectedIndex, 0)
        model.moveSelection(by: 1, count: clips.count)
        XCTAssertEqual(model.selectedIndex, 1)
        model.moveSelection(by: 0, count: 1)
        XCTAssertEqual(model.selectedIndex, 0)
        model.moveSelection(by: -1, count: 0)
        XCTAssertEqual(model.selectedIndex, 0)
    }

    func testReopeningResetsSearchAndRequestsFocus() {
        let model = HistoryViewModel()
        let previousFocus = model.focusSearch
        model.filter = .images
        model.searchText = "missing"
        model.selectedIndex = 1
        model.reset()
        XCTAssertEqual(model.filter, .all)
        XCTAssertEqual(model.searchText, "")
        XCTAssertEqual(model.selectedIndex, 0)
        XCTAssertNotEqual(model.focusSearch, previousFocus)
    }

    func testHiddenClipsMatchOnlyTheirAlias() {
        var hidden = ClipboardItem(kind: .text, text: "sample-secret-value")
        hidden.alias = "Work login"
        hidden.isSensitive = true
        var named = ClipboardItem(kind: .text, text: "git status")
        named.alias = "Shell"
        let model = HistoryViewModel()

        model.searchText = "work LOGIN"
        XCTAssertEqual(model.filteredItems(from: [hidden, named]), [hidden])
        model.searchText = "secret"
        XCTAssertTrue(model.filteredItems(from: [hidden, named]).isEmpty)
        model.searchText = "shell"
        XCTAssertEqual(model.filteredItems(from: [hidden, named]), [named], "Visible clips match their alias too")
        model.searchText = "status"
        XCTAssertEqual(model.filteredItems(from: [hidden, named]), [named])
    }

    func testWhitespaceOnlySearchShowsEverything() {
        let model = HistoryViewModel()
        model.searchText = "   \n"
        XCTAssertEqual(model.filteredItems(from: clips), clips)
    }
}
