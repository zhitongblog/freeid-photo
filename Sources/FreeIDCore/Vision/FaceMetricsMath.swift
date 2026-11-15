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
        /// Optional top-of-head Y in Vision bottom-left coords (0..1) measured from the
        /// person-segmentation mask. When nil, estimated from `faceBoundingBox` + `crownHairPad`.
        public var measuredCrownVisionY: Double?
        /// Positive when mouth corners lift relative to mouth midline or stretch into a wide grin.
        public var smileScore: Double
        /// 0..1 left-vs-right cheek luminance balance (1 = symmetric, low = side shadow).
        public var lightingUniformity: Double

        public init(
            faceCount: Int, imageWidth: Int, imageHeight: Int, faceBoundingBox: NormRect,
            chinVisionY: Double, leftEye: NormPoint, rightEye: NormPoint,
            rollDegrees: Double, yawDegrees: Double, pitchDegrees: Double,
            eyeAspectRatio: Double, lipGapRatio: Double,
            backgroundUniformity: Double, backgroundMeanHex: String,
            glassesDetected: Bool, glareOnGlasses: Bool, brightness: Double,
            neutralExpression: Bool, measuredCrownVisionY: Double? = nil,
            smileScore: Double = 0, lightingUniformity: Double = 1.0
        ) {
            self.faceCount = faceCount; self.imageWidth = imageWidth; self.imageHeight = imageHeight
            self.faceBoundingBox = faceBoundingBox; self.chinVisionY = chinVisionY
            self.leftEye = leftEye; self.rightEye = rightEye
            self.rollDegrees = rollDegrees; self.yawDegrees = yawDegrees; self.pitchDegrees = pitchDegrees
            self.eyeAspectRatio = eyeAspectRatio; self.lipGapRatio = lipGapRatio
            self.backgroundUniformity = backgroundUniformity; self.backgroundMeanHex = backgroundMeanHex
            self.glassesDetected = glassesDetected; self.glareOnGlasses = glareOnGlasses
            self.brightness = brightness; self.neutralExpression = neutralExpression
            self.measuredCrownVisionY = measuredCrownVisionY
            self.smileScore = smileScore
            self.lightingUniformity = lightingUniformity
        }
    }

    /// Thresholds for deriving boolean states from continuous landmark ratios.
    public struct Thresholds: Sendable {
        /// Eye aspect ratio at/above which eyes count as open.
        public var eyeOpen: Double = 0.18
        /// Lip-gap ratio at/below which the mouth counts as closed.
        public var mouthClosed: Double = 0.12
        /// Smile score at/below which expression counts as neutral (not grinning/laughing).
        public var maxSmileScore: Double = 0.085
        /// Fraction of the face-box height added above the box to estimate the hairline/crown
        /// when no segmentation mask is available.
        public var crownHairPad: Double = 0.25
        /// Allowed range (as a multiple of face-box height above `boxTopVisionY`) when clamping
        /// a segmentation-measured crown so stray mask noise or a raised hand can't skew framing.
        public var minCrownHairPad: Double = 0.12
        public var maxCrownHairPad: Double = 0.55
        public init() {}
    }

    public static func build(_ v: Inputs, thresholds t: Thresholds = .init()) -> FaceMetrics {
        let boxTopVisionY = v.faceBoundingBox.y + v.faceBoundingBox.h
        let rawCrownVisionY: Double
        if let measured = v.measuredCrownVisionY {
            let minCrown = boxTopVisionY + v.faceBoundingBox.h * t.minCrownHairPad
            let maxCrown = boxTopVisionY + v.faceBoundingBox.h * t.maxCrownHairPad
            rawCrownVisionY = Swift.min(maxCrown, Swift.max(minCrown, measured))
        } else {
            rawCrownVisionY = boxTopVisionY + v.faceBoundingBox.h * t.crownHairPad
        }
        let crownVisionY = min(1.0, rawCrownVisionY)

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
            neutralExpression: v.neutralExpression && (v.smileScore <= t.maxSmileScore),
            backgroundUniformity: v.backgroundUniformity, backgroundMeanHex: v.backgroundMeanHex,
            glassesDetected: v.glassesDetected, glareOnGlasses: v.glareOnGlasses,
            brightness: v.brightness,
            lightingUniformity: clamp01(v.lightingUniformity)
        )
    }

    // MARK: - Pure quality heuristics (unit-testable without Vision)

    /// Compute smile intensity from Vision bottom-left outer-lip landmarks.
    /// When smiling/laughing, mouth corners lift above the central lip line (`cornerLift > 0`)
    /// and/or the lips part into a wide grin.
    public static func smileScore(
        leftCornerY: Double, rightCornerY: Double,
        mouthCenterY: Double, mouthWidth: Double,
        lipGapRatio: Double
    ) -> Double {
        guard mouthWidth > 0.001 else { return 0 }
        let cornerMeanY = (leftCornerY + rightCornerY) / 2.0
        let cornerLift = max(0, (cornerMeanY - mouthCenterY) / mouthWidth)
        let grinBoost = max(0, lipGapRatio - 0.08) * 0.35
        return cornerLift + grinBoost
    }

    /// Map left-vs-right cheek luminance difference onto 0..1 uniformity (1 = symmetric).
    /// A difference of ≥ 0.35 (harsh half-face shadow) maps to 0.
    public static func cheekLightingUniformity(leftMeanLum: Double, rightMeanLum: Double) -> Double {
        let diff = abs(leftMeanLum - rightMeanLum)
        return clamp01(1.0 - diff / 0.35)
    }

    /// Classify glasses presence and specular lens glare from periocular & nose-bridge signals:
    /// - `bridgeEdgeRatio`: horizontal frame-bar edge contrast across the nose bridge minus
    ///   baseline vertical skin gradient on the lower nose (high when a frame crosses the bridge).
    /// - `rimContrast`: vertical edge contrast along the upper/lower lens rim zones.
    /// - `specularSpotFraction`: fraction of periocular lens pixels that are near-saturated
    ///   (`lum > 0.92`) AND stand well above median skin/eye luminance (`eyePeakContrast >= 0.26`).
    ///   Natural corneal catchlights occupy < 0.5% of the lens box, so requiring ≥ 1.2% avoids
    ///   false-positiving on bright eyes.
    public static func analyzeGlassesAndGlare(
        bridgeEdgeRatio: Double,
        rimContrast: Double,
        specularSpotFraction: Double,
        eyePeakContrast: Double
    ) -> (glassesDetected: Bool, glareOnGlasses: Bool) {
        let hasGlare = specularSpotFraction >= 0.012
            && specularSpotFraction <= 0.25
            && eyePeakContrast >= 0.26
        let hasFrames = (bridgeEdgeRatio >= 0.075 && rimContrast >= 0.055)
            || bridgeEdgeRatio >= 0.12
        return (glassesDetected: hasFrames || hasGlare, glareOnGlasses: hasGlare)
    }

    private static func clamp01(_ x: Double) -> Double { Swift.min(1, Swift.max(0, x)) }
}
