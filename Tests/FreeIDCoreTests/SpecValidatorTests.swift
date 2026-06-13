import XCTest
@testable import FreeIDCore

/// Tests SpecValidator with synthetic FaceMetrics — no Vision, no camera, no images.
/// `compliantMetrics(for:)` builds a photo that should pass every check for a spec;
/// each test then mutates one field and asserts exactly that check flips to fail/warn.
final class SpecValidatorTests: XCTestCase {

    /// Build metrics that land in the middle of every allowed range for `spec`.
    func compliantMetrics(for spec: PhotoSpec) -> FaceMetrics {
        let h = spec.outputSize.heightMM
        let headFrac = spec.headHeight.mid / h
        let eyeFromBottomFrac = spec.eyeLineFromBottom.mid / h
        let crownY = 0.10
        return FaceMetrics(
            imageWidth: spec.pixelWidth, imageHeight: spec.pixelHeight, faceCount: 1,
            crownY: crownY, chinY: crownY + headFrac,
            eyeLineY: 1.0 - eyeFromBottomFrac, faceCenterX: 0.5,
            rollDegrees: 0, yawDegrees: 0, pitchDegrees: 0,
            eyesOpen: true, mouthClosed: true, neutralExpression: true,
            backgroundUniformity: max(spec.background.minUniformity, 0.95),
            backgroundMeanHex: spec.background.hex,
            glassesDetected: false, glareOnGlasses: false, brightness: 0.6
        )
    }

    func lib() throws -> SpecLibrary { try SpecLibrary.bundled() }

    func spec(_ id: String) throws -> PhotoSpec {
        let s = try lib().spec(id: id)
        return try XCTUnwrap(s, "spec \(id) should exist")
    }

    // MARK: - Happy path: every bundled spec has a compliant configuration.

    func testAllBundledSpecsHaveACompliantConfiguration() throws {
        let library = try lib()
        XCTAssertFalse(library.specs.isEmpty, "library should not be empty")
        for s in library.specs {
            let report = SpecValidator.validate(compliantMetrics(for: s), against: s)
            XCTAssertTrue(report.isCompliant,
                "\(s.id) should be compliant; failures: \(report.failures.map(\.id))")
            XCTAssertEqual(report.overall, .pass, "\(s.id) should be all-pass")
        }
    }

    // MARK: - Geometry

    func testHeadTooLargeFails() throws {
        let s = try spec("us-passport")
        var m = compliantMetrics(for: s)
        m = with(m) { $0.chinY = $0.crownY + (s.headHeight.max + 5) / s.outputSize.heightMM }
        let r = SpecValidator.validate(m, against: s)
        XCTAssertFalse(r.isCompliant)
        XCTAssertEqual(check(r, "headHeight").status, .fail)
    }

    func testHeadTooSmallFails() throws {
        let s = try spec("us-passport")
        var m = compliantMetrics(for: s)
        m = with(m) { $0.chinY = $0.crownY + (s.headHeight.min - 5) / s.outputSize.heightMM }
        let r = SpecValidator.validate(m, against: s)
        XCTAssertEqual(check(r, "headHeight").status, .fail)
    }

    func testOffCenterFailsForStrictSpecButOnlyWarnsForEditAllowed() throws {
        // Strict (US): centering is a hard fail — nothing may be cropped/altered.
        let us = try spec("us-passport")
        let mUS = with(compliantMetrics(for: us)) { $0.faceCenterX = 0.75 }
        XCTAssertEqual(check(SpecValidator.validate(mUS, against: us), "centering").status, .fail)
        // Edit-allowed (CN): centering is auto-fixable by crop → warning, shutter still unlocks.
        let cn = try spec("cn-1inch")
        let mCN = with(compliantMetrics(for: cn)) { $0.faceCenterX = 0.75 }
        let r = SpecValidator.validate(mCN, against: cn)
        XCTAssertEqual(check(r, "centering").status, .warn)
        XCTAssertTrue(r.isCompliant, "post-fixable warning must not block capture")
    }

    func testTiltedHeadFails() throws {
        let s = try spec("cn-1inch")
        let m = with(compliantMetrics(for: s)) { $0.rollDegrees = 15 }
        XCTAssertEqual(check(SpecValidator.validate(m, against: s), "pose").status, .fail)
    }

    // MARK: - Presence / count

    func testNoFaceFails() throws {
        let s = try spec("cn-1inch")
        let m = with(compliantMetrics(for: s)) { $0.faceCount = 0 }
        XCTAssertEqual(check(SpecValidator.validate(m, against: s), "faceCount").status, .fail)
    }

    func testMultipleFacesFails() throws {
        let s = try spec("cn-1inch")
        let m = with(compliantMetrics(for: s)) { $0.faceCount = 2 }
        XCTAssertEqual(check(SpecValidator.validate(m, against: s), "faceCount").status, .fail)
    }

    // MARK: - Expression / eyes

    func testClosedEyesIsAdvisoryNotBlocking() throws {
        // Eye/mouth detection from landmarks is unreliable, so it advises but never blocks.
        let s = try spec("us-passport")
        let m = with(compliantMetrics(for: s)) { $0.eyesOpen = false }
        let r = SpecValidator.validate(m, against: s)
        XCTAssertEqual(check(r, "eyesOpen").status, .warn)
        XCTAssertTrue(r.isCompliant, "unreliable eye detection must not lock the shutter")
    }

    func testOpenMouthIsAdvisoryNotBlocking() throws {
        let s = try spec("us-passport")
        let m = with(compliantMetrics(for: s)) { $0.mouthClosed = false }
        let r = SpecValidator.validate(m, against: s)
        XCTAssertEqual(check(r, "mouthClosed").status, .warn)
        XCTAssertTrue(r.isCompliant, "false 'mouth open' must never block capture")
    }

    // MARK: - Lighting

    func testTooDarkFailsForStrictSpec() throws {
        let s = try spec("us-passport")
        let m = with(compliantMetrics(for: s)) { $0.brightness = 0.1 }
        XCTAssertEqual(check(SpecValidator.validate(m, against: s), "exposure").status, .fail)
    }

    func testTooBrightFailsForStrictSpec() throws {
        let s = try spec("us-passport")
        let m = with(compliantMetrics(for: s)) { $0.brightness = 0.99 }
        XCTAssertEqual(check(SpecValidator.validate(m, against: s), "exposure").status, .fail)
    }

    /// The core of the per-country policy: for an edit-allowed spec, fixable problems
    /// (framing + background + exposure) never block capture; only the physically
    /// un-fixable essentials do.
    func testEditAllowedSpecOnlyBlocksOnPhysicalEssentials() throws {
        let cn = try spec("cn-1inch")
        // Every post-fixable thing wrong at once...
        var m = compliantMetrics(for: cn)
        m = with(m) {
            $0.faceCenterX = 0.8                 // centering
            $0.brightness = 0.15                 // exposure
            $0.backgroundUniformity = 0.3        // bg uniformity
            $0.backgroundMeanHex = "#3366CC"     // bg color
            $0.chinY = $0.crownY + (cn.headHeight.max + 8) / cn.outputSize.heightMM // head too big
        }
        let r1 = SpecValidator.validate(m, against: cn)
        XCTAssertTrue(r1.isCompliant, "fixable problems must not block capture for edit-allowed specs")
        XCTAssertEqual(r1.overall, .warn)
        // ...but a reliable, decisive essential wrong (no face) DOES block, even for CN.
        let m2 = with(m) { $0.faceCount = 0 }
        let r2 = SpecValidator.validate(m2, against: cn)
        XCTAssertFalse(r2.isCompliant, "no face detected must block capture")
        XCTAssertEqual(check(r2, "faceCount").status, .fail)
    }

    // MARK: - Glasses

    func testGlassesIsAdvisoryNotBlocking() throws {
        // Glasses detection isn't reliable (and isn't wired yet) — advisory, never blocks.
        let s = try spec("us-passport") // glasses forbidden
        let m = with(compliantMetrics(for: s)) { $0.glassesDetected = true }
        let r = SpecValidator.validate(m, against: s)
        XCTAssertNotEqual(check(r, "glasses").status, .fail)
        XCTAssertTrue(r.isCompliant)
    }

    // MARK: - The EUREKA: background-color policy is per-country

    func testWrongBackgroundFailsForStrictCountry() throws {
        let s = try spec("us-passport") // strict
        let m = with(compliantMetrics(for: s)) { $0.backgroundMeanHex = "#3366CC" }
        let r = SpecValidator.validate(m, against: s)
        XCTAssertEqual(check(r, "background.color").status, .fail,
            "US forbids edited photos, so a wrong real background is a hard fail")
        XCTAssertFalse(r.isCompliant)
    }

    func testWrongBackgroundOnlyWarnsForEditAllowedCountry() throws {
        let s = try spec("cn-1inch") // allowed
        let m = with(compliantMetrics(for: s)) { $0.backgroundMeanHex = "#3366CC" }
        let r = SpecValidator.validate(m, against: s)
        XCTAssertEqual(check(r, "background.color").status, .warn,
            "China allows replacement, so wrong background is only a warning")
        XCTAssertTrue(r.isCompliant, "warnings do not block compliance")
        XCTAssertEqual(r.overall, .warn)
    }

    func testUnevenBackgroundFails() throws {
        let s = try spec("us-passport")
        let m = with(compliantMetrics(for: s)) { $0.backgroundUniformity = 0.4 }
        XCTAssertEqual(check(SpecValidator.validate(m, against: s), "background.uniformity").status, .fail)
    }

    // MARK: - Helpers

    private func check(_ r: ComplianceReport, _ id: String) -> CheckResult {
        guard let c = r.checks.first(where: { $0.id == id }) else {
            XCTFail("no check '\(id)' in report for \(r.specID)")
            return CheckResult(id: id, title: "", status: .fail, detail: "")
        }
        return c
    }
}

/// Mutate a copy of a value type via a closure (FaceMetrics has `let` fields, so we
/// rebuild it). Keeps the tests terse without making FaceMetrics mutable in production.
@discardableResult
func with(_ m: FaceMetrics, _ mutate: (inout MutableMetrics) -> Void) -> FaceMetrics {
    var mm = MutableMetrics(m)
    mutate(&mm)
    return mm.build()
}

/// Mutable mirror of FaceMetrics used only by tests.
struct MutableMetrics {
    var imageWidth, imageHeight, faceCount: Int
    var crownY, chinY, eyeLineY, faceCenterX: Double
    var rollDegrees, yawDegrees, pitchDegrees: Double
    var eyesOpen, mouthClosed, neutralExpression: Bool
    var backgroundUniformity: Double
    var backgroundMeanHex: String
    var glassesDetected, glareOnGlasses: Bool
    var brightness: Double

    init(_ m: FaceMetrics) {
        imageWidth = m.imageWidth; imageHeight = m.imageHeight; faceCount = m.faceCount
        crownY = m.crownY; chinY = m.chinY; eyeLineY = m.eyeLineY; faceCenterX = m.faceCenterX
        rollDegrees = m.rollDegrees; yawDegrees = m.yawDegrees; pitchDegrees = m.pitchDegrees
        eyesOpen = m.eyesOpen; mouthClosed = m.mouthClosed; neutralExpression = m.neutralExpression
        backgroundUniformity = m.backgroundUniformity; backgroundMeanHex = m.backgroundMeanHex
        glassesDetected = m.glassesDetected; glareOnGlasses = m.glareOnGlasses; brightness = m.brightness
    }
    func build() -> FaceMetrics {
        FaceMetrics(
            imageWidth: imageWidth, imageHeight: imageHeight, faceCount: faceCount,
            crownY: crownY, chinY: chinY, eyeLineY: eyeLineY, faceCenterX: faceCenterX,
            rollDegrees: rollDegrees, yawDegrees: yawDegrees, pitchDegrees: pitchDegrees,
            eyesOpen: eyesOpen, mouthClosed: mouthClosed, neutralExpression: neutralExpression,
            backgroundUniformity: backgroundUniformity, backgroundMeanHex: backgroundMeanHex,
            glassesDetected: glassesDetected, glareOnGlasses: glareOnGlasses, brightness: brightness)
    }
}
