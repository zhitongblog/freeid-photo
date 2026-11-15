import Foundation

/// Geometry + quality measurements extracted from a single framed image.
///
/// This is the seam between Apple Vision (iOS/macOS only, lives in the engine layer)
/// and SpecValidator (pure logic, this is its only input). Everything here is
/// normalized to the image's own coordinate space, origin top-left, so the validator
/// never touches pixels, CVPixelBuffer, or the camera.
///
///   y = 0.0  ┌───────────────┐  top of image
///            │     ███        │  crownY   (top of head)
///            │    █████       │
///            │   ██ ◉ ◉ ██    │  eyeLineY (average pupil height)
///            │    █████       │
///            │     ███        │  chinY    (bottom of chin)
///   y = 1.0  └───────────────┘  bottom of image
///
/// headFraction = chinY - crownY  → maps to mm via the spec's output height.
public struct FaceMetrics: Codable, Sendable, Equatable {
    public let imageWidth: Int
    public let imageHeight: Int

    /// Number of distinct faces detected. Spec requires exactly 1.
    public let faceCount: Int

    public let crownY: Double      // 0..1, top of head
    public let chinY: Double       // 0..1, bottom of chin
    public let eyeLineY: Double    // 0..1, average eye height
    public let faceCenterX: Double // 0..1, horizontal face center

    public let rollDegrees: Double  // head tilt (in-plane)
    public let yawDegrees: Double   // turn left/right
    public let pitchDegrees: Double // nod up/down

    public let eyesOpen: Bool
    public let mouthClosed: Bool
    public let neutralExpression: Bool

    /// 0..1 background evenness (1 = perfectly uniform). From person-segmentation mask.
    public let backgroundUniformity: Double
    /// Mean background color behind/around the subject, as #RRGGBB.
    public let backgroundMeanHex: String

    public let glassesDetected: Bool
    public let glareOnGlasses: Bool

    /// 0..1 overall scene luminance. Too low = underexposed, too high = blown out.
    public let brightness: Double
    /// 0..1 left-vs-right facial lighting symmetry (1 = balanced, low = harsh side shadow / 阴阳脸).
    public let lightingUniformity: Double

    public init(
        imageWidth: Int, imageHeight: Int, faceCount: Int,
        crownY: Double, chinY: Double, eyeLineY: Double, faceCenterX: Double,
        rollDegrees: Double, yawDegrees: Double, pitchDegrees: Double,
        eyesOpen: Bool, mouthClosed: Bool, neutralExpression: Bool,
        backgroundUniformity: Double, backgroundMeanHex: String,
        glassesDetected: Bool, glareOnGlasses: Bool, brightness: Double,
        lightingUniformity: Double = 1.0
    ) {
        self.imageWidth = imageWidth; self.imageHeight = imageHeight; self.faceCount = faceCount
        self.crownY = crownY; self.chinY = chinY; self.eyeLineY = eyeLineY
        self.faceCenterX = faceCenterX
        self.rollDegrees = rollDegrees; self.yawDegrees = yawDegrees; self.pitchDegrees = pitchDegrees
        self.eyesOpen = eyesOpen; self.mouthClosed = mouthClosed; self.neutralExpression = neutralExpression
        self.backgroundUniformity = backgroundUniformity; self.backgroundMeanHex = backgroundMeanHex
        self.glassesDetected = glassesDetected; self.glareOnGlasses = glareOnGlasses
        self.brightness = brightness
        self.lightingUniformity = lightingUniformity
    }

    private enum CodingKeys: String, CodingKey {
        case imageWidth, imageHeight, faceCount
        case crownY, chinY, eyeLineY, faceCenterX
        case rollDegrees, yawDegrees, pitchDegrees
        case eyesOpen, mouthClosed, neutralExpression
        case backgroundUniformity, backgroundMeanHex
        case glassesDetected, glareOnGlasses, brightness, lightingUniformity
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        imageWidth = try c.decode(Int.self, forKey: .imageWidth)
        imageHeight = try c.decode(Int.self, forKey: .imageHeight)
        faceCount = try c.decode(Int.self, forKey: .faceCount)
        crownY = try c.decode(Double.self, forKey: .crownY)
        chinY = try c.decode(Double.self, forKey: .chinY)
        eyeLineY = try c.decode(Double.self, forKey: .eyeLineY)
        faceCenterX = try c.decode(Double.self, forKey: .faceCenterX)
        rollDegrees = try c.decode(Double.self, forKey: .rollDegrees)
        yawDegrees = try c.decode(Double.self, forKey: .yawDegrees)
        pitchDegrees = try c.decode(Double.self, forKey: .pitchDegrees)
        eyesOpen = try c.decode(Bool.self, forKey: .eyesOpen)
        mouthClosed = try c.decode(Bool.self, forKey: .mouthClosed)
        neutralExpression = try c.decode(Bool.self, forKey: .neutralExpression)
        backgroundUniformity = try c.decode(Double.self, forKey: .backgroundUniformity)
        backgroundMeanHex = try c.decode(String.self, forKey: .backgroundMeanHex)
        glassesDetected = try c.decode(Bool.self, forKey: .glassesDetected)
        glareOnGlasses = try c.decode(Bool.self, forKey: .glareOnGlasses)
        brightness = try c.decode(Double.self, forKey: .brightness)
        lightingUniformity = try c.decodeIfPresent(Double.self, forKey: .lightingUniformity) ?? 1.0
    }

    /// Chin-to-crown height as a fraction of image height (0..1).
    public var headFraction: Double { chinY - crownY }
    /// Eye line distance from the bottom edge as a fraction of image height (0..1).
    public var eyeFromBottomFraction: Double { 1.0 - eyeLineY }
}
