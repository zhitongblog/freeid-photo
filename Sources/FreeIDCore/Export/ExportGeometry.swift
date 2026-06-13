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
}
