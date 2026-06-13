import Foundation

/// Loads and indexes the bundled PhotoSpec data.
///
/// Specs ship as individual JSON files in `Sources/FreeIDCore/Specs/` (one per
/// country+doc-type) so the data is human-reviewable, diff-friendly, and could later
/// be community-sourced via pull request without touching code. They are loaded from
/// `Bundle.module` at runtime.
public struct SpecLibrary: Sendable {
    public let specs: [PhotoSpec]
    private let byID: [String: PhotoSpec]

    public init(specs: [PhotoSpec]) {
        self.specs = specs.sorted { $0.id < $1.id }
        self.byID = Dictionary(uniqueKeysWithValues: specs.map { ($0.id, $0) })
    }

    public func spec(id: String) -> PhotoSpec? { byID[id] }
    public func specs(country: String) -> [PhotoSpec] {
        specs.filter { $0.country.caseInsensitiveCompare(country) == .orderedSame }
    }
    public var countries: [String] { Array(Set(specs.map { $0.country })).sorted() }

    /// Load every `*.json` spec bundled with FreeIDCore.
    public static func bundled() throws -> SpecLibrary {
        try load(from: .module)
    }

    /// Load every `*.json` spec from the given bundle.
    public static func load(from bundle: Bundle) throws -> SpecLibrary {
        guard let dir = bundle.url(forResource: "Specs", withExtension: nil)
            ?? bundle.resourceURL?.appendingPathComponent("Specs")
        else { throw SpecLibraryError.specsDirectoryMissing }

        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []
        let jsonURLs = urls.filter { $0.pathExtension == "json" }
        guard !jsonURLs.isEmpty else { throw SpecLibraryError.noSpecsFound }

        let decoder = JSONDecoder()
        var loaded: [PhotoSpec] = []
        for url in jsonURLs {
            let data = try Data(contentsOf: url)
            loaded.append(try decoder.decode(PhotoSpec.self, from: data))
        }
        return SpecLibrary(specs: loaded)
    }
}

public enum SpecLibraryError: Error, CustomStringConvertible {
    case specsDirectoryMissing
    case noSpecsFound
    public var description: String {
        switch self {
        case .specsDirectoryMissing: return "Specs resource directory not found in bundle"
        case .noSpecsFound: return "No .json spec files found"
        }
    }
}
