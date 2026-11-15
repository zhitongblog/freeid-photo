import XCTest
@testable import FreeIDCore

final class FaceMetricsMathTests: XCTestCase {

    /// A face centered in the frame, eyes in the upper third (Vision bottom-left coords).
    func sampleInputs() -> FaceMetricsMath.Inputs {
        FaceMetricsMath.Inputs(
            faceCount: 1, imageWidth: 1000, imageHeight: 1000,
            faceBoundingBox: .init(x: 0.3, y: 0.35, w: 0.4, h: 0.4), // bottom-left origin
            chinVisionY: 0.36,                                       // near box bottom
            leftEye: .init(x: 0.42, y: 0.62), rightEye: .init(x: 0.58, y: 0.62),
            rollDegrees: 0, yawDegrees: 0, pitchDegrees: 0,
            eyeAspectRatio: 0.30, lipGapRatio: 0.05,
            backgroundUniformity: 0.95, backgroundMeanHex: "#FFFFFF",
            glassesDetected: false, glareOnGlasses: false, brightness: 0.6,
            neutralExpression: true)
    }

    func testYAxisIsFlippedToTopLeft() {
        let m = FaceMetricsMath.build(sampleInputs())
        // Eyes at vision y 0.62 → top-left y 0.38.
        XCTAssertEqual(m.eyeLineY, 0.38, accuracy: 0.0001)
        // Chin at vision y 0.36 → top-left y 0.64.
        XCTAssertEqual(m.chinY, 0.64, accuracy: 0.0001)
        // Crown is above the box top (vision 0.75) plus hair pad → top-left y < chin.
        XCTAssertLessThan(m.crownY, m.chinY)
    }

    func testFaceCenterIsMeanOfEyes() {
        let m = FaceMetricsMath.build(sampleInputs())
        XCTAssertEqual(m.faceCenterX, 0.5, accuracy: 0.0001)
    }

    func testHeadFractionIsPositiveAndSane() {
        let m = FaceMetricsMath.build(sampleInputs())
        XCTAssertGreaterThan(m.headFraction, 0)
        XCTAssertLessThan(m.headFraction, 1)
    }

    func testEyeOpenThreshold() {
        var open = sampleInputs(); open.eyeAspectRatio = 0.25
        XCTAssertTrue(FaceMetricsMath.build(open).eyesOpen)
        var closed = sampleInputs(); closed.eyeAspectRatio = 0.05
        XCTAssertFalse(FaceMetricsMath.build(closed).eyesOpen)
    }

    func testMouthClosedThreshold() {
        var closed = sampleInputs(); closed.lipGapRatio = 0.05
        XCTAssertTrue(FaceMetricsMath.build(closed).mouthClosed)
        var open = sampleInputs(); open.lipGapRatio = 0.4
        XCTAssertFalse(FaceMetricsMath.build(open).mouthClosed)
    }

    func testCoordinatesClampedTo01() {
        var weird = sampleInputs()
        weird.faceBoundingBox = .init(x: 0.1, y: 0.9, w: 0.4, h: 0.4) // top extends past 1.0
        let m = FaceMetricsMath.build(weird)
        XCTAssertGreaterThanOrEqual(m.crownY, 0)
        XCTAssertLessThanOrEqual(m.crownY, 1)
    }

    func testMeasuredCrownOverridesHairPadWithinPhysiologicalBounds() {
        var inputs = sampleInputs()
        // Face box y=0.35, h=0.40 → boxTop = 0.75.
        // Measured crown at 0.90 (+0.375h above boxTop) is within [0.12h, 0.55h] → top-left crownY = 0.10.
        inputs.measuredCrownVisionY = 0.90
        let m = FaceMetricsMath.build(inputs)
        XCTAssertEqual(m.crownY, 0.10, accuracy: 0.0001)

        // Outlier mask noise way above head (0.99 → +0.60h) clamps to maxCrownHairPad (0.75 + 0.4*0.55 = 0.97 → crownY = 0.03).
        inputs.measuredCrownVisionY = 0.99
        let clampedHigh = FaceMetricsMath.build(inputs)
        XCTAssertEqual(clampedHigh.crownY, 0.03, accuracy: 0.0001)
    }

    func testSmileScoreFlipsNeutralExpressionToFalse() {
        let neutralScore = FaceMetricsMath.smileScore(
            leftCornerY: 0.30, rightCornerY: 0.30, mouthCenterY: 0.295, mouthWidth: 0.25, lipGapRatio: 0.03)
        XCTAssertLessThanOrEqual(neutralScore, 0.085)

        let bigGrinScore = FaceMetricsMath.smileScore(
            leftCornerY: 0.34, rightCornerY: 0.34, mouthCenterY: 0.30, mouthWidth: 0.24, lipGapRatio: 0.14)
        XCTAssertGreaterThan(bigGrinScore, 0.085)

        var smiling = sampleInputs()
        smiling.smileScore = bigGrinScore
        XCTAssertFalse(FaceMetricsMath.build(smiling).neutralExpression)
    }

    func testCheekLightingUniformityDetectsSideShadow() {
        XCTAssertEqual(FaceMetricsMath.cheekLightingUniformity(leftMeanLum: 0.62, rightMeanLum: 0.62), 1.0, accuracy: 0.001)
        let shadowed = FaceMetricsMath.cheekLightingUniformity(leftMeanLum: 0.72, rightMeanLum: 0.48)
        XCTAssertLessThan(shadowed, 0.60)
    }

    func testGlassesAndGlareHeuristics() {
        // Bare face with tiny pupil catchlight (< 0.5%) must NOT false-positive.
        let bare = FaceMetricsMath.analyzeGlassesAndGlare(
            bridgeEdgeRatio: 0.02, rimContrast: 0.02, specularSpotFraction: 0.004, eyePeakContrast: 0.30)
        XCTAssertFalse(bare.glassesDetected)
        XCTAssertFalse(bare.glareOnGlasses)

        // Distinct eyeglass bridge + lower rim without glare.
        let framed = FaceMetricsMath.analyzeGlassesAndGlare(
            bridgeEdgeRatio: 0.095, rimContrast: 0.070, specularSpotFraction: 0.002, eyePeakContrast: 0.12)
        XCTAssertTrue(framed.glassesDetected)
        XCTAssertFalse(framed.glareOnGlasses)

        // Specular lens glare (even on rimless glasses).
        let glaring = FaceMetricsMath.analyzeGlassesAndGlare(
            bridgeEdgeRatio: 0.03, rimContrast: 0.03, specularSpotFraction: 0.035, eyePeakContrast: 0.34)
        XCTAssertTrue(glaring.glassesDetected)
        XCTAssertTrue(glaring.glareOnGlasses)
    }

    func testBackwardsCompatibleDecodingWithoutLightingUniformity() throws {
        let legacyJSON = """
        {
          "imageWidth": 1000, "imageHeight": 1000, "faceCount": 1,
          "crownY": 0.1, "chinY": 0.7, "eyeLineY": 0.4, "faceCenterX": 0.5,
          "rollDegrees": 0, "yawDegrees": 0, "pitchDegrees": 0,
          "eyesOpen": true, "mouthClosed": true, "neutralExpression": true,
          "backgroundUniformity": 0.95, "backgroundMeanHex": "#FFFFFF",
          "glassesDetected": false, "glareOnGlasses": false, "brightness": 0.6
        }
        """
        let decoded = try JSONDecoder().decode(FaceMetrics.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(decoded.lightingUniformity, 1.0, accuracy: 0.0001)
    }
}

final class ExportGeometryTests: XCTestCase {

    func spec() throws -> PhotoSpec {
        try XCTUnwrap(try SpecLibrary.bundled().spec(id: "us-passport"))
    }

    /// Metrics where the head fills a known fraction; crop should size so the head
    /// lands at the spec's target head fraction.
    func testCropSizesHeadToTargetFraction() throws {
        let s = try spec()
        let m = FaceMetrics(
            imageWidth: 2000, imageHeight: 2000, faceCount: 1,
            crownY: 0.30, chinY: 0.60, eyeLineY: 0.40, faceCenterX: 0.5,
            rollDegrees: 0, yawDegrees: 0, pitchDegrees: 0,
            eyesOpen: true, mouthClosed: true, neutralExpression: true,
            backgroundUniformity: 0.95, backgroundMeanHex: "#FFFFFF",
            glassesDetected: false, glareOnGlasses: false, brightness: 0.6)
        let rect = ExportGeometry.cropRect(imageWidth: 2000, imageHeight: 2000, spec: s, metrics: m)

        // head = 0.30 * 2000 = 600px; crop sized so the head lands at the margin-biased target.
        let targetHeadMM = s.headHeight.min + 0.15 * (s.headHeight.max - s.headHeight.min)
        let targetHeadFrac = targetHeadMM / s.outputSize.heightMM
        XCTAssertEqual(rect.height, 600.0 / targetHeadFrac, accuracy: 1.0)
        // Square spec → crop width ≈ height.
        XCTAssertEqual(rect.width, rect.height, accuracy: 1.0)
    }

    func testCropStaysInsideImage() throws {
        let s = try spec()
        // Face pushed to the edge; crop must clamp inside bounds.
        let m = FaceMetrics(
            imageWidth: 1200, imageHeight: 1200, faceCount: 1,
            crownY: 0.02, chinY: 0.22, eyeLineY: 0.10, faceCenterX: 0.95,
            rollDegrees: 0, yawDegrees: 0, pitchDegrees: 0,
            eyesOpen: true, mouthClosed: true, neutralExpression: true,
            backgroundUniformity: 0.95, backgroundMeanHex: "#FFFFFF",
            glassesDetected: false, glareOnGlasses: false, brightness: 0.6)
        let r = ExportGeometry.cropRect(imageWidth: 1200, imageHeight: 1200, spec: s, metrics: m)
        XCTAssertGreaterThanOrEqual(r.x, 0)
        XCTAssertGreaterThanOrEqual(r.y, 0)
        XCTAssertLessThanOrEqual(r.x + r.width, 1200.0001)
        XCTAssertLessThanOrEqual(r.y + r.height, 1200.0001)
    }
}

/// Reprojection is the fix for "face position easily fails": raw full-frame metrics are
/// reframed through the export crop before validation, so head/eye/centering describe the
/// photo that would actually be produced — not the whole sensor frame.
final class ReprojectionTests: XCTestCase {

    func spec() throws -> PhotoSpec {
        // us-passport is the worst case: strict edit policy keeps geometry as HARD fails,
        // so before the fix these checks lock the shutter forever.
        try XCTUnwrap(try SpecLibrary.bundled().spec(id: "us-passport"))
    }

    /// A typical front-camera selfie: head ~25% of a 3:4 frame, roughly centered. This is a
    /// COMPLIANT shot once cropped, yet raw full-frame validation fails head-height + eye-line.
    func smallCenteredFace() -> FaceMetrics {
        FaceMetrics(
            imageWidth: 1080, imageHeight: 1440, faceCount: 1,
            crownY: 0.20, chinY: 0.45, eyeLineY: 0.30, faceCenterX: 0.52,
            rollDegrees: 0, yawDegrees: 0, pitchDegrees: 0,
            eyesOpen: true, mouthClosed: true, neutralExpression: true,
            backgroundUniformity: 0.95, backgroundMeanHex: "#FFFFFF",
            glassesDetected: false, glareOnGlasses: false, brightness: 0.6)
    }

    func status(_ report: ComplianceReport, _ id: String) -> CheckStatus? {
        report.checks.first { $0.id == id }?.status
    }

    func testRawFullFrameMetricsWronglyFail() throws {
        let s = try spec()
        let report = SpecValidator.validate(smallCenteredFace(), against: s)
        // The bug: a fine selfie reads as "head too small" and "eyes too high" on the full frame.
        XCTAssertEqual(status(report, "headHeight"), .fail)
        XCTAssertEqual(status(report, "eyeLine"), .fail)
        XCTAssertFalse(report.isCompliant)
    }

    func testReprojectionMakesTheSameFaceCompliant() throws {
        let s = try spec()
        let framed = ExportGeometry.reprojected(smallCenteredFace(), spec: s)
        let report = SpecValidator.validate(framed, against: s)
        XCTAssertEqual(status(report, "headHeight"), .pass)
        XCTAssertEqual(status(report, "eyeLine"), .pass)
        XCTAssertEqual(status(report, "centering"), .pass)
        XCTAssertTrue(report.isCompliant, "reframed selfie should unlock the shutter")
    }

    /// When the crop is unclamped, head/eye/center land exactly on the spec's target values.
    func testUnclampedReprojectionLandsOnTarget() throws {
        let s = try spec()
        let framed = ExportGeometry.reprojected(smallCenteredFace(), spec: s)
        let targetHeadMM = s.headHeight.min + 0.15 * (s.headHeight.max - s.headHeight.min)
        let targetHeadFrac = targetHeadMM / s.outputSize.heightMM
        let targetEyeFromBottom = s.eyeLineFromBottom.mid / s.outputSize.heightMM
        XCTAssertEqual(framed.headFraction, targetHeadFrac, accuracy: 0.005)
        XCTAssertEqual(framed.eyeFromBottomFraction, targetEyeFromBottom, accuracy: 0.005)
        XCTAssertEqual(framed.faceCenterX, 0.5, accuracy: 0.005)
    }

    /// Reprojection must NOT paper over real problems. A face jammed against the frame edge
    /// can't be centered by any crop, so centering stays a fail after reframing.
    func testReprojectionPreservesGenuineEdgeFailure() throws {
        let s = try spec()
        var offEdge = smallCenteredFace()
        offEdge = FaceMetrics(
            imageWidth: offEdge.imageWidth, imageHeight: offEdge.imageHeight, faceCount: 1,
            crownY: offEdge.crownY, chinY: offEdge.chinY, eyeLineY: offEdge.eyeLineY,
            faceCenterX: 0.95, // crammed to the right edge
            rollDegrees: 0, yawDegrees: 0, pitchDegrees: 0,
            eyesOpen: true, mouthClosed: true, neutralExpression: true,
            backgroundUniformity: 0.95, backgroundMeanHex: "#FFFFFF",
            glassesDetected: false, glareOnGlasses: false, brightness: 0.6)
        let report = SpecValidator.validate(ExportGeometry.reprojected(offEdge, spec: s), against: s)
        XCTAssertEqual(status(report, "centering"), .fail)
    }

    /// Non-geometry fields (pose, exposure, background) are not touched by reprojection.
    func testReprojectionPreservesNonGeometryFields() throws {
        let s = try spec()
        let raw = smallCenteredFace()
        let framed = ExportGeometry.reprojected(raw, spec: s)
        XCTAssertEqual(framed.rollDegrees, raw.rollDegrees)
        XCTAssertEqual(framed.brightness, raw.brightness)
        XCTAssertEqual(framed.backgroundUniformity, raw.backgroundUniformity)
        XCTAssertEqual(framed.faceCount, raw.faceCount)
    }

    /// No face → nothing to reframe; pass through unchanged so "no face detected" still surfaces.
    func testReprojectionNoOpWhenNoFace() throws {
        let s = try spec()
        let none = FaceMetrics(
            imageWidth: 1080, imageHeight: 1440, faceCount: 0,
            crownY: 0, chinY: 0, eyeLineY: 0, faceCenterX: 0.5,
            rollDegrees: 0, yawDegrees: 0, pitchDegrees: 0,
            eyesOpen: false, mouthClosed: false, neutralExpression: false,
            backgroundUniformity: 0.9, backgroundMeanHex: "#FFFFFF",
            glassesDetected: false, glareOnGlasses: false, brightness: 0.5)
        XCTAssertEqual(ExportGeometry.reprojected(none, spec: s), none)
    }
}
