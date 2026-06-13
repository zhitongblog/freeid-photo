import Foundation

public enum CheckStatus: String, Codable, Sendable {
    case pass   // meets the spec
    case warn   // borderline / advisory (e.g. strict-country background advice)
    case fail   // violates the spec
}

/// One line item in a compliance report, e.g. "Head height", "Eyes open".
public struct CheckResult: Codable, Sendable, Equatable {
    /// Stable key, e.g. "headHeight", "background.color".
    public let id: String
    public let title: LocalizedText
    public let status: CheckStatus
    /// Human-readable reason, including the measured value vs the allowed range.
    public let detail: LocalizedText

    public init(id: String, title: LocalizedText, status: CheckStatus, detail: LocalizedText) {
        self.id = id; self.title = title; self.status = status; self.detail = detail
    }
}

/// The result of validating one FaceMetrics against one PhotoSpec.
///
/// `overall` is .fail if any check fails, else .warn if any warns, else .pass.
/// The live viewfinder unlocks the shutter only when `isCompliant` is true.
public struct ComplianceReport: Codable, Sendable, Equatable {
    public let specID: String
    public let checks: [CheckResult]

    public init(specID: String, checks: [CheckResult]) {
        self.specID = specID
        self.checks = checks
    }

    public var overall: CheckStatus {
        if checks.contains(where: { $0.status == .fail }) { return .fail }
        if checks.contains(where: { $0.status == .warn }) { return .warn }
        return .pass
    }

    /// True only when every check passes (warnings do not block — they advise).
    public var isCompliant: Bool { !checks.contains { $0.status == .fail } }

    public var failures: [CheckResult] { checks.filter { $0.status == .fail } }
    public var warnings: [CheckResult] { checks.filter { $0.status == .warn } }
}
