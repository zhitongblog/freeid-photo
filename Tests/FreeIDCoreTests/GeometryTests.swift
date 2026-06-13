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

        // head = 0.30 * 2000 = 600px; targetHeadFrac = 30.15/51 ≈ 0.591
        // cropH ≈ 600 / 0.591 ≈ 1015px
        let targetHeadFrac = s.headHeight.mid / s.outputSize.heightMM
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
