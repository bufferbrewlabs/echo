import AppKit
import Combine
import os

final class HistoryStore: ObservableObject {
    static let defaultMaxItems = 300

    @Published private(set) var items: [ClipboardItem] = []

    private let maxItems: Int
    private let supportDir: URL
    private let imagesDir: URL
    private let indexFile: URL
    private let fileManager = FileManager.default
    /// Decoded thumbnails, so list rows don't re-read PNGs from disk on every render.
    private let imageCache = NSCache<NSString, NSImage>()
    private let log = Logger(subsystem: "com.kartikjain.echo", category: "HistoryStore")

    init(directory: URL? = nil, maxItems: Int = HistoryStore.defaultMaxItems) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.maxItems = maxItems
        supportDir = directory ?? base.appendingPathComponent("Echo", isDirectory: true)
        imagesDir = supportDir.appendingPathComponent("Images", isDirectory: true)
        indexFile = supportDir.appendingPathComponent("history.json")
        imageCache.countLimit = 100
        createPrivateDirectory(supportDir)
        createPrivateDirectory(imagesDir)
        load()
    }

    // MARK: - Mutations

    func addText(_ text: String) {
        if let existing = items.first(where: { $0.kind == .text && $0.text == text }) {
            touch(existing) // Recopying a pinned clip must preserve its identity and pin.
            return
        }
        items.insert(ClipboardItem(kind: .text, text: text), at: 0)
        trimAndSave()
    }

    func addImage(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }

        let fileName = "\(UUID().uuidString).png"
        let url = imagesDir.appendingPathComponent(fileName)
        do {
            try png.write(to: url, options: .atomic)
            restrictToOwner(url)
        } catch {
            // Never record a clip whose image is missing; it would render and paste as nothing.
            log.error("Could not save image clip: \(error.localizedDescription, privacy: .public)")
            return
        }

        items.insert(ClipboardItem(kind: .image, imageFileName: fileName), at: 0)
        trimAndSave()
    }

    /// Move an existing item back to the top (used when re-pasting from history).
    func touch(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        let existing = items.remove(at: idx)
        items.insert(existing, at: 0)
        trimAndSave()
    }

    /// Save an explicit edit without rewriting or deduplicating its source clip.
    @discardableResult
    func saveText(_ text: String, alias: String, isSensitive: Bool, replacing item: ClipboardItem? = nil) -> UUID? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let name = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSensitive || !name.isEmpty else { return nil }
        let savedID: UUID
        if let item {
            guard item.kind == .text,
                  let index = items.firstIndex(where: { $0.id == item.id }) else { return nil }
            items[index].text = text
            items[index].alias = name.isEmpty ? nil : name
            items[index].isSensitive = isSensitive
            savedID = item.id
        } else {
            var clip = ClipboardItem(kind: .text, text: text)
            clip.alias = name.isEmpty ? nil : name
            clip.isSensitive = isSensitive
            savedID = clip.id
            items.insert(clip, at: 0)
        }
        trimAndSave()
        return savedID
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        trimAndSave()
    }

    func remove(_ item: ClipboardItem) {
        deleteImageFile(for: item)
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearAll() {
        items.forEach(deleteImageFile(for:))
        items.removeAll()
        save()
    }

    func image(for item: ClipboardItem) -> NSImage? {
        guard item.kind == .image, let name = item.imageFileName else { return nil }
        if let cached = imageCache.object(forKey: name as NSString) { return cached }
        guard let image = NSImage(contentsOf: imagesDir.appendingPathComponent(name)) else { return nil }
        imageCache.setObject(image, forKey: name as NSString)
        return image
    }

    // MARK: - Persistence

    private func trimAndSave() {
        let pinned = items.filter(\.isPinned)
        let recent = items.filter { !$0.isPinned }
        recent.dropFirst(maxItems).forEach(deleteImageFile(for:))
        items = pinned + recent.prefix(maxItems)
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: indexFile, options: .atomic)
            restrictToOwner(indexFile)
        } catch {
            log.error("Could not save history: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func load() {
        guard fileManager.fileExists(atPath: indexFile.path) else { return }
        let decoded: [ClipboardItem]
        do {
            decoded = try JSONDecoder().decode([ClipboardItem].self, from: Data(contentsOf: indexFile))
        } catch {
            // Keep the unreadable file instead of letting the next save overwrite it,
            // and leave images alone so the history can still be recovered by hand.
            preserveUnreadableHistory(error)
            return
        }
        items = decoded.filter(\.isPinned) + decoded.filter { !$0.isPinned }
        removeOrphanedImages()
    }

    private func preserveUnreadableHistory(_ error: Error) {
        let stamp = Int(Date().timeIntervalSince1970)
        let backup = supportDir.appendingPathComponent("history.unreadable-\(stamp).json")
        do {
            try fileManager.moveItem(at: indexFile, to: backup)
            log.error("History was unreadable (\(error.localizedDescription, privacy: .public)); kept it as \(backup.lastPathComponent, privacy: .public)")
        } catch {
            log.error("History was unreadable and could not be backed up: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Deletes image files no clip refers to, such as those left by a crash between
    /// writing an image and saving the history index.
    private func removeOrphanedImages() {
        let referenced = Set(items.compactMap(\.imageFileName))
        guard let files = try? fileManager.contentsOfDirectory(atPath: imagesDir.path) else { return }
        for file in files where file.hasSuffix(".png") && !referenced.contains(file) {
            try? fileManager.removeItem(at: imagesDir.appendingPathComponent(file))
        }
    }

    private func deleteImageFile(for item: ClipboardItem) {
        guard item.kind == .image, let name = item.imageFileName else { return }
        imageCache.removeObject(forKey: name as NSString)
        try? fileManager.removeItem(at: imagesDir.appendingPathComponent(name))
    }

    // History can hold anything a user copied, so keep it readable by this user only.
    private func createPrivateDirectory(_ url: URL) {
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true,
                                         attributes: [.posixPermissions: 0o700])
        try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    private func restrictToOwner(_ url: URL) {
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
