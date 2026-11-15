@testable import Echo
import XCTest

final class ClipboardItemTests: XCTestCase {
    func testLegacyHistoryWithoutNewerFieldsStillDecodes() throws {
        let clip = ClipboardItem(kind: .text, text: "Existing history")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(clip)) as? [String: Any])
        object.removeValue(forKey: "isPinned")
        object.removeValue(forKey: "isSensitive")
        object.removeValue(forKey: "alias")

        let loaded = try JSONDecoder().decode(ClipboardItem.self, from: JSONSerialization.data(withJSONObject: object))

        XCTAssertEqual(loaded, clip)
        XCTAssertFalse(loaded.isPinned)
        XCTAssertFalse(loaded.isSensitive)
        XCTAssertNil(loaded.alias)
    }

    func testEncodingRoundTripsEveryField() throws {
        var clip = ClipboardItem(kind: .text, text: "Body")
        clip.isPinned = true
        clip.alias = "Name"
        clip.isSensitive = true

        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: JSONEncoder().encode(clip))

        XCTAssertEqual(decoded, clip)
    }

    func testDecodingRejectsUnknownKind() {
        let json = #"{"id":"\#(UUID().uuidString)","kind":"video","date":0}"#
        XCTAssertThrowsError(try JSONDecoder().decode(ClipboardItem.self, from: Data(json.utf8)))
    }

    func testPreviewTrimsTextAndLabelsEmptyOrImageClips() {
        XCTAssertEqual(ClipboardItem(kind: .text, text: "  hello\n").preview, "hello")
        XCTAssertEqual(ClipboardItem(kind: .text, text: " \n\t").preview, "(empty)")
        XCTAssertEqual(ClipboardItem(kind: .text, text: nil).preview, "(empty)")
        XCTAssertEqual(ClipboardItem(kind: .image, imageFileName: "a.png").preview, "[Image]")
    }

    func testPreviewPrefersAliasAndNeverRevealsHiddenText() {
        var clip = ClipboardItem(kind: .text, text: "sample-secret-value")
        clip.alias = "Work login"
        XCTAssertEqual(clip.preview, "Work login")

        clip.isSensitive = true
        XCTAssertEqual(clip.preview, "Work login")

        clip.alias = ""
        XCTAssertEqual(clip.preview, "Hidden text")
        XCTAssertFalse(clip.preview.contains("secret"))
    }
}
