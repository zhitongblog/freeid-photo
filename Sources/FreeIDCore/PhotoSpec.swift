import Foundation

/// A country + document-type photo specification.
///
/// All physical measurements are in millimetres so specs read like the official
/// government tables they come from. Pixel dimensions are derived from `dpi`, never
/// stored, so they can't drift out of sync with the physical size.
///
///   outputSize (mm)  ──/25.4──▶ inches ──×dpi──▶ pixel dimensions
///
/// `digitalEditPolicy` is the per-country switch that drives whether AI background
/// replacement is offered (US = .strict / forbidden, China etc. = .allowed). See
/// EditPolicy for why this is data, not a global flag.
public struct PhotoSpec: Codable, Sendable, Identifiable, Equatable {
    /// Stable slug, e.g. "us-passport", "cn-visa".
    public let id: String
    /// ISO 3166-1 alpha-2, e.g. "US", "CN".
    public let country: String
    public let docType: DocType
    public let displayName: LocalizedText

    /// Final printed/exported size.
    public let outputSize: PhysicalSize
    public let dpi: Int

    /// Allowed chin-to-crown head height in the final photo.
    public let headHeight: RangeMM
    /// Allowed distance from the eye line to the bottom edge of the final photo.
    public let eyeLineFromBottom: RangeMM

    public let background: BackgroundRule
    public let digitalEditPolicy: EditPolicy
    public let expression: ExpressionRule
    public let glasses: GlassesRule
    /// Constraints for digital submission (online forms). nil = no digital file rules.
    public let fileSpec: FileSpec?

    /// URL of the official government source this spec was transcribed from.
    public let officialSourceURL: String
    /// ISO-8601 date the spec values were last verified against the official source.
    public let lastVerified: String

    public init(
        id: String, country: String, docType: DocType, displayName: LocalizedText,
        outputSize: PhysicalSize, dpi: Int, headHeight: RangeMM, eyeLineFromBottom: RangeMM,
        background: BackgroundRule, digitalEditPolicy: EditPolicy, expression: ExpressionRule,
        glasses: GlassesRule, fileSpec: FileSpec?, officialSourceURL: String, lastVerified: String
    ) {
        self.id = id; self.country = country; self.docType = docType; self.displayName = displayName
        self.outputSize = outputSize; self.dpi = dpi; self.headHeight = headHeight
        self.eyeLineFromBottom = eyeLineFromBottom; self.background = background
        self.digitalEditPolicy = digitalEditPolicy; self.expression = expression
        self.glasses = glasses; self.fileSpec = fileSpec
        self.officialSourceURL = officialSourceURL; self.lastVerified = lastVerified
    }

    /// Final width in pixels at the spec's DPI.
    public var pixelWidth: Int { Int((outputSize.widthMM / 25.4 * Double(dpi)).rounded()) }
    /// Final height in pixels at the spec's DPI.
    public var pixelHeight: Int { Int((outputSize.heightMM / 25.4 * Double(dpi)).rounded()) }
    /// width / height — the crop aspect ratio the camera framing must match.
    public var aspectRatio: Double { outputSize.widthMM / outputSize.heightMM }

    /// Build a custom-sized ID-photo spec (in millimetres) with standard ICAO head/eye
    /// proportions and optional digital file-size limits (in KB).
    public static func custom(
        widthMM: Double, heightMM: Double, dpi: Int = 300,
        backgroundHex: String = "#FFFFFF",
        minKB: Int? = nil, maxKB: Int? = nil
    ) -> PhotoSpec {
        let w = max(10, widthMM)
        let h = max(10, heightMM)
        let fileSpec: FileSpec? = (minKB != nil || maxKB != nil)
            ? FileSpec(pixelWidth: nil, pixelHeight: nil, minKB: minKB, maxKB: maxKB, format: "JPEG")
            : nil
        return PhotoSpec(
            id: "custom-\(Int(w))x\(Int(h))",
            country: "CUSTOM",
            docType: .general,
            displayName: LocalizedText(en: "Custom \(Int(w))×\(Int(h))mm", zh: "自定义 \(Int(w))×\(Int(h))mm"),
            outputSize: PhysicalSize(widthMM: w, heightMM: h),
            dpi: dpi,
            headHeight: RangeMM(min: (h * 0.58 * 10).rounded() / 10, max: (h * 0.69 * 10).rounded() / 10),
            eyeLineFromBottom: RangeMM(min: (h * 0.55 * 10).rounded() / 10, max: (h * 0.62 * 10).rounded() / 10),
            background: BackgroundRule(
                name: LocalizedText(en: "White", zh: "白色"),
                hex: backgroundHex, toleranceDeltaE: 12, minUniformity: 0.85),
            digitalEditPolicy: .allowed,
            expression: ExpressionRule(neutral: true, mouthClosed: true, eyesOpen: true),
            glasses: .allowedNoGlare,
            fileSpec: fileSpec,
            officialSourceURL: "",
            lastVerified: ""
        )
    }
}

public enum DocType: String, Codable, Sendable, CaseIterable {
    case passport, visa, idCard, driverLicense, residencePermit, general
}

/// Whether the destination country tolerates digital alteration of the photo.
///
/// This is the EUREKA of the whole product: it is NOT a global setting. The US
/// (2026: harshest enforcement in 20 years, zero tolerance for "digitally altered"
/// images, ~15-20% app-photo rejection rate) forbids AI background replacement and
/// retouching, so its specs are `.strict`. China and many others allow it, so theirs
/// are `.allowed`. The export pipeline reads this field to decide which tools to offer.
public enum EditPolicy: String, Codable, Sendable {
    /// No digital alteration. Offer crop / rotate / resize only; guide a real background.
    case strict
    /// Digital background replacement and color normalization are acceptable.
    case allowed
}

public struct PhysicalSize: Codable, Sendable, Equatable {
    public let widthMM: Double
    public let heightMM: Double
    public init(widthMM: Double, heightMM: Double) {
        self.widthMM = widthMM; self.heightMM = heightMM
    }
}

/// Inclusive millimetre range.
public struct RangeMM: Codable, Sendable, Equatable {
    public let min: Double
    public let max: Double
    public init(min: Double, max: Double) { self.min = min; self.max = max }
    public func contains(_ v: Double) -> Bool { v >= min && v <= max }
    public var mid: Double { (min + max) / 2 }
}

public struct BackgroundRule: Codable, Sendable, Equatable {
    public let name: LocalizedText
    /// Target background color as #RRGGBB.
    public let hex: String
    /// Allowed CIEDE2000 color deviation from `hex`.
    public let toleranceDeltaE: Double
    /// Minimum allowed background uniformity, 0..1 (1 = perfectly even).
    public let minUniformity: Double
    public init(name: LocalizedText, hex: String, toleranceDeltaE: Double, minUniformity: Double) {
        self.name = name; self.hex = hex
        self.toleranceDeltaE = toleranceDeltaE; self.minUniformity = minUniformity
    }
}

public enum GlassesRule: String, Codable, Sendable {
    /// Glasses not permitted at all (most modern passports).
    case forbidden
    /// Glasses allowed only if there is no glare and eyes are fully visible.
    case allowedNoGlare
}

public struct ExpressionRule: Codable, Sendable, Equatable {
    public let neutral: Bool
    public let mouthClosed: Bool
    public let eyesOpen: Bool
    public init(neutral: Bool, mouthClosed: Bool, eyesOpen: Bool) {
        self.neutral = neutral; self.mouthClosed = mouthClosed; self.eyesOpen = eyesOpen
    }
}

public struct FileSpec: Codable, Sendable, Equatable {
    public let pixelWidth: Int?
    public let pixelHeight: Int?
    public let minKB: Int?
    public let maxKB: Int?
    public let format: String
    public init(pixelWidth: Int?, pixelHeight: Int?, minKB: Int?, maxKB: Int?, format: String) {
        self.pixelWidth = pixelWidth; self.pixelHeight = pixelHeight
        self.minKB = minKB; self.maxKB = maxKB; self.format = format
    }
}

/// Minimal bilingual string. The app's locale picks the field; falls back to English.
public struct LocalizedText: Codable, Sendable, Equatable, ExpressibleByStringLiteral {
    public let en: String
    public let zh: String
    public init(en: String, zh: String) { self.en = en; self.zh = zh }
    /// String-literal init uses the same text for both languages (handy for tests).
    public init(stringLiteral value: String) { self.en = value; self.zh = value }
    public func text(forLanguage code: String) -> String {
        code.lowercased().hasPrefix("zh") ? zh : en
    }
}
