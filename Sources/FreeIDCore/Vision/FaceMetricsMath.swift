import Foundation

/// Pure conversion from Vision-style observations to FaceMetrics. No Vision import, so
/// the coordinate math (the part most likely to have an off-by-flip bug) is unit-testable
/// without a camera, a device, or a real face.
///
/// Vision reports geometry in a NORMALIZED, BOTTOM-LEFT-origin space (x→right, y→up).
/// FaceMetrics uses a TOP-LEFT-origin space (x→right, y→down) to match image pixels:
///
///     vision y = 1 ─┐ top of image      freeid y = 0 ─┐ top of image
///                   │                                  │
///     vision y = 0 ─┘ bottom            freeid y = 1 ─┘ bottom
///
///     freeidY = 1 - visionY      (x is identical in both)
public enum FaceMetricsMath {

    /// Normalized rect, bottom-left origin (Vision's `boundingBox` convention).
    public struct NormRect: Sendable { public var x, y, w, h: Double
        public init(x: Double, y: Double, w: Double, h: Double) { self.x = x; self.y = y; self.w = w; self.h = h } }
    /// Normalized point, bottom-left origin.
    public struct NormPoint: Sendable { public var x, y: Double
        public init(x: Double, y: Double) { self.x = x; self.y = y } }

    public struct Inputs: Sendable {
        public var faceCount: Int
        public var imageWidth: Int
        public var imageHeight: Int
        public var faceBoundingBox: NormRect   // Vision face box (bottom-left)
        public var chinVisionY: Double         // lowest chin-contour y, Vision coords (0..1)
        public var leftEye: NormPoint          // eye/pupil center, Vision coords
        public var rightEye: NormPoint
        public var rollDegrees: Double
        public var yawDegrees: Double
        public var pitchDegrees: Double
        public var eyeAspectRatio: Double      // (eye height / eye width); low = closed
        public var lipGapRatio: Double         // inner-lip gap / mouth width; high = open
        public var backgroundUniformity: Double
        public var backgroundMeanHex: String
        public var glassesDetected: Bool
        public var glareOnGlasses: Bool
        public var brightness: Double
        public var neutralExpression: Bool

        public init(
            faceCount: Int, imageWidth: Int, imageHeight: Int, faceBoundingBox: NormRect,
            chinVisionY: Double, leftEye: NormPoint, rightEye: NormPoint,
            rollDegrees: Double, yawDegrees: Double, pitchDegrees: Double,
            eyeAspectRatio: Double, lipGapRatio: Double,
            backgroundUniformity: Double, backgroundMeanHex: String,
            glassesDetected: Bool, glareOnGlasses: Bool, brightness: Double,
            neutralExpression: Bool
        ) {
            self.faceCount = faceCount; self.imageWidth = imageWidth; self.imageHeight = imageHeight
            self.faceBoundingBox = faceBoundingBox; self.chinVisionY = chinVisionY
            self.leftEye = leftEye; self.rightEye = rightEye
            self.rollDegrees = rollDegrees; self.yawDegrees = yawDegrees; self.pitchDegrees = pitchDegrees
            self.eyeAspectRatio = eyeAspectRatio; self.lipGapRatio = lipGapRatio
            self.backgroundUniformity = backgroundUniformity; self.backgroundMeanHex = backgroundMeanHex
            self.glassesDetected = glassesDetected; self.glareOnGlasses = glareOnGlasses
            self.brightness = brightness; self.neutralExpression = neutralExpression
        }
    }

    /// Thresholds for deriving boolean states from continuous landmark ratios.
    public struct Thresholds: Sendable {
        /// Eye aspect ratio at/above which eyes count as open.
        public var eyeOpen: Double = 0.18
        /// Lip-gap ratio at/below which the mouth counts as closed.
        public var mouthClosed: Double = 0.12
        /// Fraction of the face-box height added above the box to estimate the hairline/crown.
        /// Vision's face box stops near the eyebrows/forehead; the true top of the head (hair)
        /// sits well above it, so this must be generous or the crop measures the head too short
        /// and ends up cutting the crown / leaving no margin. Calibrated on real photos.
        public var crownHairPad: Double = 0.25
        public init() {}
    }

    public static func build(_ v: Inputs, thresholds t: Thresholds = .init()) -> FaceMetrics {
        // Vision's face box stops around the hairline; add a small pad to estimate the
        // crown (top of head/hair). Approximate by design — calibrated on real photos.
        let boxTopVisionY = v.faceBoundingBox.y + v.faceBoundingBox.h
        let crownVisionY = min(1.0, boxTopVisionY + v.faceBoundingBox.h * t.crownHairPad)

        let crownY = 1.0 - crownVisionY
        let chinY = 1.0 - v.chinVisionY
        let eyeLineY = 1.0 - (v.leftEye.y + v.rightEye.y) / 2.0
        let faceCenterX = (v.leftEye.x + v.rightEye.x) / 2.0

        return FaceMetrics(
            imageWidth: v.imageWidth, imageHeight: v.imageHeight, faceCount: v.faceCount,
            crownY: clamp01(crownY), chinY: clamp01(chinY),
            eyeLineY: clamp01(eyeLineY), faceCenterX: clamp01(faceCenterX),
            rollDegrees: v.rollDegrees, yawDegrees: v.yawDegrees, pitchDegrees: v.pitchDegrees,
            eyesOpen: v.eyeAspectRatio >= t.eyeOpen,
            mouthClosed: v.lipGapRatio <= t.mouthClosed,
            neutralExpression: v.neutralExpression,
            backgroundUniformity: v.backgroundUniformity, backgroundMeanHex: v.backgroundMeanHex,
            glassesDetected: v.glassesDetected, glareOnGlasses: v.glareOnGlasses,
            brightness: v.brightness
        )
    }

    private static func clamp01(_ x: Double) -> Double { Swift.min(1, Swift.max(0, x)) }
}
