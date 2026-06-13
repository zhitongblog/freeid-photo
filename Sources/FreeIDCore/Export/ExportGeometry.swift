import Foundation

/// Pure crop math: given the source image size, a spec, and where the face is, compute
/// the crop rectangle (top-left origin, pixels) that places the head at the spec's
/// required size and the eyes at the spec's required height. No image library, so it's
/// unit-testable.
///
///   target head fraction = spec.headHeight.mid / outputHeight   (how tall the head should be)
///   cropHeight           = measuredHeadPixels / targetHeadFraction
///   cropWidth            = cropHeight × spec.aspectRatio
///   vertical placement   = put the eye line at (1 - eyeFromBottom/outputHeight) of cropHeight
///   horizontal placement = center on the detected face center
public enum ExportGeometry {

    public struct PixelRect: Equatable, Sendable {
        public var x, y, width, height: Double
        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x; self.y = y; self.width = width; self.height = height
        }
    }

    public static func cropRect(
        imageWidth: Int, imageHeight: Int, spec: PhotoSpec, metrics: FaceMetrics
    ) -> PixelRect {
        let srcW = Double(imageWidth), srcH = Double(imageHeight)

        let targetHeadFrac = spec.headHeight.mid / spec.outputSize.heightMM
        let targetEyeFromBottomFrac = spec.eyeLineFromBottom.mid / spec.outputSize.heightMM
        let eyeFromTopFrac = 1.0 - targetEyeFromBottomFrac

        let headPx = max(1.0, (metrics.chinY - metrics.crownY) * srcH)
        var cropH = headPx / targetHeadFrac
        var cropW = cropH * spec.aspectRatio

        // Don't request a crop larger than the source; scale both down preserving aspect.
        if cropW > srcW { let k = srcW / cropW; cropW *= k; cropH *= k }
        if cropH > srcH { let k = srcH / cropH; cropW *= k; cropH *= k }

        let eyeYpx = metrics.eyeLineY * srcH
        let centerXpx = metrics.faceCenterX * srcW

        var left = centerXpx - cropW / 2
        var top = eyeYpx - eyeFromTopFrac * cropH

        // Keep the crop inside the image.
        left = min(max(0, left), srcW - cropW)
        top = min(max(0, top), srcH - cropH)

        return PixelRect(x: left, y: top, width: cropW, height: cropH)
    }

    /// Re-express raw, full-frame `FaceMetrics` in the coordinate space of the export crop.
    ///
    /// SpecValidator assumes its input is measured on an image *already framed to the spec's
    /// aspect ratio* — head/eye fractions map straight to millimetres only under that
    /// assumption. But the live camera and an arbitrary photo file are NOT pre-framed: the
    /// face is a small region of a full sensor frame. Validating those raw metrics makes the
    /// head look far too short, the eye line wrong, and the face off-centre — so head-height /
    /// eye-position / centering "easily fail" even when the export would produce a perfectly
    /// compliant photo.
    ///
    /// This reprojects through the *same* crop the export pipeline will apply, so validating
    /// the result answers the honest question: "if I shoot now, will the exported photo pass?"
    /// When the face sits comfortably inside the frame the crop is unclamped and head/eye/
    /// centre land on their target values (a pass). When the face is jammed against an edge or
    /// too small/large to crop cleanly, the crop clamps and the reprojected values fall out of
    /// range — surfacing the genuine "move back / centre yourself" guidance the user needs.
    public static func reprojected(_ m: FaceMetrics, spec: PhotoSpec) -> FaceMetrics {
        guard m.faceCount >= 1, m.imageWidth > 0, m.imageHeight > 0 else { return m }
        let srcW = Double(m.imageWidth), srcH = Double(m.imageHeight)
        let crop = cropRect(imageWidth: m.imageWidth, imageHeight: m.imageHeight, spec: spec, metrics: m)
        guard crop.width > 0, crop.height > 0 else { return m }

        // Top-left, y-down throughout (FaceMetrics' convention), so the map is a plain
        // translate-and-scale into the crop rectangle. Intentionally NOT clamped to 0..1:
        // an out-of-range value is the signal that the face spilled past the crop edge.
        func mapY(_ y: Double) -> Double { (y * srcH - crop.y) / crop.height }
        func mapX(_ x: Double) -> Double { (x * srcW - crop.x) / crop.width }

        return FaceMetrics(
            imageWidth: Int(crop.width.rounded()), imageHeight: Int(crop.height.rounded()),
            faceCount: m.faceCount,
            crownY: mapY(m.crownY), chinY: mapY(m.chinY),
            eyeLineY: mapY(m.eyeLineY), faceCenterX: mapX(m.faceCenterX),
            rollDegrees: m.rollDegrees, yawDegrees: m.yawDegrees, pitchDegrees: m.pitchDegrees,
            eyesOpen: m.eyesOpen, mouthClosed: m.mouthClosed, neutralExpression: m.neutralExpression,
            backgroundUniformity: m.backgroundUniformity, backgroundMeanHex: m.backgroundMeanHex,
            glassesDetected: m.glassesDetected, glareOnGlasses: m.glareOnGlasses,
            brightness: m.brightness)
    }
}
