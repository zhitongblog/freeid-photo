import Foundation
import FreeIDCore

/// Local-only store of recent upright original photos + their measured `FaceMetrics`, allowing
/// the user to re-export a previous shot into any new document spec later without re-shooting.
///
/// Stored strictly inside the app's local `Application Support/PhotoHistory` container with
/// `isExcludedFromBackup = true` — nothing ever leaves the device, and users can delete one or
/// all items at any time.
final class PhotoHistoryStore: @unchecked Sendable {

    struct Entry: Codable, Identifiable, Sendable, Equatable {
        let id: UUID
        let createdAt: Date
        let metrics: FaceMetrics
        var lastSpecID: String
    }

    private let maxEntries: Int
    private let rootURL: URL
    private let lock = NSLock()

    init(directory: URL? = nil, maxEntries: Int = 12) {
        self.maxEntries = maxEntries
        if let directory {
            self.rootURL = directory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.rootURL = appSupport.appendingPathComponent("PhotoHistory", isDirectory: true)
        }
        ensureDirectory()
    }

    private var indexURL: URL { rootURL.appendingPathComponent("index.json") }
    private func imageURL(for id: UUID) -> URL { rootURL.appendingPathComponent("\(id.uuidString).jpg") }

    private func ensureDirectory() {
        var dir = rootURL
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        var rv = URLResourceValues()
        rv.isExcludedFromBackup = true
        try? dir.setResourceValues(rv)
    }

    func loadEntries() -> [Entry] {
        lock.lock(); defer { lock.unlock() }
        return readIndexUnlocked()
    }

    @discardableResult
    func saveOriginal(jpegData: Data, metrics: FaceMetrics, specID: String) -> Entry? {
        lock.lock(); defer { lock.unlock() }
        ensureDirectory()
        let entry = Entry(id: UUID(), createdAt: Date(), metrics: metrics, lastSpecID: specID)
        var imgURL = imageURL(for: entry.id)
        guard (try? jpegData.write(to: imgURL, options: .atomic)) != nil else { return nil }
        var rv = URLResourceValues()
        rv.isExcludedFromBackup = true
        try? imgURL.setResourceValues(rv)

        var entries = readIndexUnlocked()
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            let dropped = entries.suffix(from: maxEntries)
            for old in dropped {
                try? FileManager.default.removeItem(at: imageURL(for: old.id))
            }
            entries = Array(entries.prefix(maxEntries))
        }
        writeIndexUnlocked(entries)
        return entry
    }

    func imageData(for id: UUID) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return try? Data(contentsOf: imageURL(for: id))
    }

    func delete(id: UUID) {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: imageURL(for: id))
        let entries = readIndexUnlocked().filter { $0.id != id }
        writeIndexUnlocked(entries)
    }

    func clearAll() {
        lock.lock(); defer { lock.unlock() }
        let entries = readIndexUnlocked()
        for e in entries {
            try? FileManager.default.removeItem(at: imageURL(for: e.id))
        }
        try? FileManager.default.removeItem(at: indexURL)
    }

    private func readIndexUnlocked() -> [Entry] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let decoded = try? dec.decode([Entry].self, from: data) else { return [] }
        return decoded.filter { FileManager.default.fileExists(atPath: imageURL(for: $0.id).path) }
    }

    private func writeIndexUnlocked(_ entries: [Entry]) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(entries) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
