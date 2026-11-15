import AppKit
import XCTest

/// A fresh directory under the system temp folder, removed when the test finishes.
func makeTemporaryDirectory(_ testCase: XCTestCase) -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("echo-tests-\(UUID().uuidString)", isDirectory: true)
    testCase.addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    return directory
}

/// A small solid-colour bitmap built without a window server or graphics context.
func makeImage(width: Int = 2, height: Int = 2) -> NSImage {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    for x in 0..<width {
        for y in 0..<height { rep.setColor(.red, atX: x, y: y) }
    }
    let image = NSImage(size: NSSize(width: width, height: height))
    image.addRepresentation(rep)
    return image
}

func imagesDirectory(in directory: URL) -> URL {
    directory.appendingPathComponent("Images", isDirectory: true)
}

func posixPermissions(_ url: URL) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return try XCTUnwrap(attributes[.posixPermissions] as? NSNumber).intValue
}
