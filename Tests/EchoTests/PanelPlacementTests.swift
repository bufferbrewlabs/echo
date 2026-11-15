import AppKit
@testable import Echo
import XCTest

final class PanelPlacementTests: XCTestCase {
    private let screen = NSRect(x: 0, y: 0, width: 1000, height: 800)
    private let size = NSSize(width: 300, height: 400)

    private func frame(caretAt point: NSPoint, size: NSSize? = nil, visible: NSRect? = nil) -> NSRect {
        StatusBarController.panelFrame(anchor: NSRect(origin: point, size: NSSize(width: 2, height: 16)),
                                       size: size ?? self.size, visible: visible ?? screen, gap: 8)
    }

    func testOpensBelowTheCaretWhenThereIsRoom() {
        XCTAssertEqual(frame(caretAt: NSPoint(x: 100, y: 600)), NSRect(x: 100, y: 192, width: 300, height: 400))
    }

    func testFlipsAboveTheCaretNearTheBottomOfTheScreen() {
        XCTAssertEqual(frame(caretAt: NSPoint(x: 100, y: 100)), NSRect(x: 100, y: 124, width: 300, height: 400))
    }

    func testPinsToTheBottomWhenNeitherSideFits() {
        let result = frame(caretAt: NSPoint(x: 100, y: 390))
        XCTAssertEqual(result.minY, 0)
        XCTAssertLessThanOrEqual(result.maxY, screen.maxY)
    }

    func testStaysOnScreenNearTheRightEdge() {
        XCTAssertEqual(frame(caretAt: NSPoint(x: 950, y: 600)).maxX, screen.maxX)
    }

    func testShrinksToFitASmallScreen() {
        let small = NSRect(x: 0, y: 0, width: 250, height: 300)
        let result = frame(caretAt: NSPoint(x: 10, y: 200), visible: small)
        XCTAssertEqual(result.size, NSSize(width: 250, height: 300))
        XCTAssertTrue(small.contains(result))
    }

    func testRespectsAnOffsetSecondaryScreen() {
        let secondary = NSRect(x: 1440, y: -200, width: 1200, height: 900)
        let result = frame(caretAt: NSPoint(x: 1400, y: 500), visible: secondary)
        XCTAssertEqual(result.minX, secondary.minX)
        XCTAssertTrue(secondary.contains(result))
    }
}
