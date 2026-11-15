import AppKit
@testable import Echo
import XCTest

/// Drives the monitor against a private, uniquely named pasteboard so tests never
/// read or overwrite the user's real clipboard.
final class ClipboardMonitorTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var store: HistoryStore!
    private var monitor: ClipboardMonitor!

    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    override func setUp() {
        super.setUp()
        pasteboard = NSPasteboard(name: NSPasteboard.Name("com.kartikjain.echo.tests.\(UUID().uuidString)"))
        store = HistoryStore(directory: makeTemporaryDirectory(self))
        monitor = ClipboardMonitor(store: store, pasteboard: pasteboard)
    }

    override func tearDown() {
        monitor.stop()
        pasteboard.releaseGlobally()
        super.tearDown()
    }

    private func copy(_ text: String, markedAs extraTypes: [NSPasteboard.PasteboardType] = []) {
        pasteboard.clearContents()
        pasteboard.declareTypes([.string] + extraTypes, owner: nil)
        pasteboard.setString(text, forType: .string)
        for type in extraTypes { pasteboard.setData(Data(), forType: type) }
    }

    func testRecordsNewTextOnce() {
        copy("hello")
        monitor.poll()
        monitor.poll() // No pasteboard change: nothing new is recorded.

        XCTAssertEqual(store.items.map(\.text), ["hello"])
    }

    func testIgnoresContentPresentBeforeMonitoringStarted() {
        copy("already there")
        let fresh = ClipboardMonitor(store: store, pasteboard: pasteboard)
        fresh.poll()

        XCTAssertTrue(store.items.isEmpty)
    }

    func testIgnoresEmptyText() {
        copy("")
        monitor.poll()

        XCTAssertTrue(store.items.isEmpty)
    }

    func testSkipsPasswordManagerAndTransientClips() {
        copy("hunter2", markedAs: [Self.concealed])
        monitor.poll()
        copy("one-time code", markedAs: [Self.transient])
        monitor.poll()

        XCTAssertTrue(store.items.isEmpty, "Concealed or transient clips must never reach history")

        copy("normal text")
        monitor.poll()
        XCTAssertEqual(store.items.map(\.text), ["normal text"])
    }

    func testRecordsImages() throws {
        pasteboard.clearContents()
        pasteboard.setData(try XCTUnwrap(makeImage().tiffRepresentation), forType: .tiff)
        monitor.poll()

        XCTAssertEqual(store.items.map(\.kind), [.image])
    }

    func testOwnPasteTouchesTheChosenClipInsteadOfAddingOne() {
        store.addText("older")
        store.addText("newer")
        let chosen = store.items[1]

        monitor.pendingProgrammaticItem = chosen
        copy("older")
        monitor.poll()

        XCTAssertNil(monitor.pendingProgrammaticItem)
        XCTAssertEqual(store.items.map(\.id).first, chosen.id)
        XCTAssertEqual(store.items.count, 2)
    }

    func testShouldIgnoreRecognisesEveryMarker() {
        XCTAssertFalse(ClipboardMonitor.shouldIgnore(types: nil))
        XCTAssertFalse(ClipboardMonitor.shouldIgnore(types: [.string, .tiff]))
        for marker in ClipboardMonitor.ignoredTypes {
            XCTAssertTrue(ClipboardMonitor.shouldIgnore(types: [.string, marker]), marker.rawValue)
        }
    }
}
