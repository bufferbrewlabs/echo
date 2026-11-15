@testable import Echo
import XCTest

final class HistoryStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = makeTemporaryDirectory(self)
    }

    private func makeStore(maxItems: Int = HistoryStore.defaultMaxItems) -> HistoryStore {
        HistoryStore(directory: directory, maxItems: maxItems)
    }

    private var historyFile: URL { directory.appendingPathComponent("history.json") }

    private func imageFile(for clip: ClipboardItem) throws -> URL {
        imagesDirectory(in: directory).appendingPathComponent(try XCTUnwrap(clip.imageFileName))
    }

    // MARK: Recording and ordering

    func testNewClipsGoFirstAndRecopiedTextMovesToTopWithoutDuplicating() {
        let store = makeStore()
        store.addText("first")
        store.addText("second")
        let first = store.items[1]

        store.addText("first")

        XCTAssertEqual(store.items.map(\.text), ["first", "second"])
        XCTAssertEqual(store.items[0].id, first.id, "Recopying keeps the clip's identity")
    }

    func testPinSurvivesRecopyAndHistoryLimit() {
        let store = makeStore()
        store.addText("Keep me")
        let pinned = store.items[0]
        store.togglePin(pinned)
        for index in 0..<302 { store.addText("Recent \(index)") }
        XCTAssertEqual(store.items.count, 301)
        XCTAssertEqual(store.items.first?.id, pinned.id)

        store.addText("Keep me")
        XCTAssertEqual(store.items.first?.id, pinned.id)
        XCTAssertEqual(store.items.first?.isPinned, true)
        XCTAssertEqual(makeStore().items, store.items)

        store.togglePin(store.items[0])
        XCTAssertEqual(store.items.count, 300)
        XCTAssertTrue(store.items.allSatisfy { !$0.isPinned })
    }

    func testPinnedClipsLoadAheadOfRecentOnes() {
        let store = makeStore()
        store.addText("old")
        store.addText("new")
        store.togglePin(store.items[1])

        XCTAssertEqual(makeStore().items.map(\.text), ["old", "new"])
    }

    func testTouchMovesAClipToTheTopAndIgnoresUnknownClips() {
        let store = makeStore()
        store.addText("a")
        store.addText("b")
        let a = store.items[1]

        store.touch(a)
        XCTAssertEqual(store.items.map(\.text), ["a", "b"])

        store.touch(ClipboardItem(kind: .text, text: "not stored"))
        XCTAssertEqual(store.items.map(\.text), ["a", "b"])
    }

    // MARK: Editing

    func testEditCopyAndHiddenAliasSearch() {
        let store = makeStore()
        store.addText("Original full text")
        let original = store.items[0]
        XCTAssertNil(store.saveText(" ", alias: "", isSensitive: false))
        XCTAssertNil(store.saveText("Secret", alias: " ", isSensitive: true))
        XCTAssertEqual(store.items.count, 1)

        store.saveText("full text", alias: "Snippet", isSensitive: false)
        XCTAssertEqual(store.items.count, 2)
        XCTAssertTrue(store.items.contains(original))

        let newClip = store.items[0]
        store.togglePin(newClip)
        store.saveText("sample-secret-value", alias: "Work login", isSensitive: true, replacing: newClip)
        let hidden = store.items[0]
        XCTAssertEqual(hidden.id, newClip.id)
        XCTAssertEqual(hidden.isPinned, true)
        XCTAssertEqual(hidden.preview, "Work login")
        XCTAssertEqual(store.items.count, 2)

        let model = HistoryViewModel()
        model.searchText = "work LOGIN"
        XCTAssertEqual(model.filteredItems(from: store.items), [hidden])
        model.searchText = "sample-secret-value"
        XCTAssertTrue(model.filteredItems(from: store.items).isEmpty)
        XCTAssertEqual(makeStore().items, store.items)

        store.remove(hidden)
        XCTAssertEqual(store.items, [original])
    }

    func testSaveTextTrimsAliasAndDropsAnEmptyOne() throws {
        let store = makeStore()
        let id = try XCTUnwrap(store.saveText("body", alias: "  Name  ", isSensitive: false))
        XCTAssertEqual(store.items.first?.id, id)
        XCTAssertEqual(store.items.first?.alias, "Name")

        store.saveText("body 2", alias: "   ", isSensitive: false, replacing: store.items[0])
        XCTAssertNil(store.items.first?.alias)
        XCTAssertEqual(store.items.first?.text, "body 2")
    }

    func testSaveTextRefusesImagesAndClipsNoLongerInHistory() {
        let store = makeStore()
        store.addImage(makeImage())
        let image = store.items[0]

        XCTAssertNil(store.saveText("text", alias: "", isSensitive: false, replacing: image))
        XCTAssertNil(store.saveText("text", alias: "", isSensitive: false,
                                    replacing: ClipboardItem(kind: .text, text: "gone")))
        XCTAssertEqual(store.items, [image])
    }

    // MARK: Images

    func testRemovingImagesDeletesTheirFile() throws {
        let store = makeStore()
        store.addImage(makeImage())
        XCTAssertEqual(store.items.count, 1)
        let clip = store.items[0]
        let file = try imageFile(for: clip)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertNotNil(store.image(for: clip))

        store.remove(clip)

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertNil(store.image(for: clip), "A removed image must not linger in the cache")
        XCTAssertTrue(makeStore().items.isEmpty)
    }

    func testClearAllRemovesEveryClipAndImageIncludingPins() throws {
        let store = makeStore()
        store.addImage(makeImage())
        let file = try imageFile(for: store.items[0])
        store.addText("pinned")
        store.togglePin(store.items[0])

        store.clearAll()

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(makeStore().items.isEmpty)
    }

    func testImagesPushedPastTheLimitAreDeletedFromDisk() throws {
        let store = makeStore(maxItems: 2)
        store.addImage(makeImage())
        let file = try imageFile(for: store.items[0])
        store.addText("one")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        store.addText("two")

        XCTAssertEqual(store.items.map(\.text), ["two", "one"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testImageLookupIgnoresTextClipsAndMissingFiles() {
        let store = makeStore()
        XCTAssertNil(store.image(for: ClipboardItem(kind: .text, text: "x")))
        XCTAssertNil(store.image(for: ClipboardItem(kind: .image, imageFileName: "missing.png")))
    }

    func testFailedImageWriteDoesNotRecordAClip() throws {
        let store = makeStore()
        // Replace the images folder with a plain file so the PNG cannot be written.
        try FileManager.default.removeItem(at: imagesDirectory(in: directory))
        try Data().write(to: imagesDirectory(in: directory))

        store.addImage(makeImage())

        XCTAssertTrue(store.items.isEmpty)
    }

    // MARK: Persistence safety

    func testUnreadableHistoryIsKeptAsABackupInsteadOfBeingOverwritten() throws {
        try FileManager.default.createDirectory(at: imagesDirectory(in: directory), withIntermediateDirectories: true)
        let corrupt = Data("{ not json".utf8)
        try corrupt.write(to: historyFile)
        let image = imagesDirectory(in: directory).appendingPathComponent("kept.png")
        try Data("png".utf8).write(to: image)

        let store = makeStore()
        XCTAssertTrue(store.items.isEmpty)
        store.addText("after recovery")

        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("history.unreadable-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(backups[0])), corrupt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: image.path),
                      "Images of an unreadable history are left for manual recovery")
        XCTAssertEqual(makeStore().items.map(\.text), ["after recovery"])
    }

    func testLoadingRemovesOrphanedImagesButKeepsReferencedAndOtherFiles() throws {
        let store = makeStore()
        store.addImage(makeImage())
        let referenced = try imageFile(for: store.items[0])
        let orphan = imagesDirectory(in: directory).appendingPathComponent("orphan.png")
        let unrelated = imagesDirectory(in: directory).appendingPathComponent("notes.txt")
        try Data("x".utf8).write(to: orphan)
        try Data("x".utf8).write(to: unrelated)

        _ = makeStore()

        XCTAssertTrue(FileManager.default.fileExists(atPath: referenced.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }

    func testHistoryFilesAreReadableOnlyByTheOwner() throws {
        let store = makeStore()
        store.addText("private")
        store.addImage(makeImage())

        XCTAssertEqual(try posixPermissions(directory), 0o700)
        XCTAssertEqual(try posixPermissions(imagesDirectory(in: directory)), 0o700)
        XCTAssertEqual(try posixPermissions(historyFile), 0o600)
        XCTAssertEqual(try posixPermissions(imageFile(for: store.items[0])), 0o600)
    }
}
