#if canImport(CoreImage) && canImport(ImageIO)
import Foundation
import CoreImage
import ImageIO
import CoreGraphics

/// Loads image bytes into an UPRIGHT `CGImage`, applying the EXIF orientation tag.
///
/// `CGImageSourceCreateImageAtIndex` (and friends) return the raw stored pixels and drop the
/// orientation metadata. A phone portrait capture stores landscape pixels plus an orientation
/// tag, so honoring the tag is the difference between an upright headshot and one rotated 90°.
/// Every seam that turns image *data* into a `CGImage` for analysis/export must go through
/// here, or a portrait shot gets measured, cropped, and exported sideways.
public enum ImageLoading {

    /// Decode `data` into an upright CGImage. Returns nil if the bytes can't be decoded.
    public static func uprightCGImage(from data: Data, context: CIContext = CIContext()) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        return applyOrientation(cg, source: src, context: context)
    }

    /// Decode the file at `path` into an upright CGImage.
    public static func uprightCGImage(fromFile path: String, context: CIContext = CIContext()) -> CGImage? {
        let url = URL(fileURLWithPath: path)
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        return applyOrientation(cg, source: src, context: context)
    }

    private static func applyOrientation(_ cg: CGImage, source src: CGImageSource, context: CIContext) -> CGImage {
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        let orientation = (props?[kCGImagePropertyOrientation] as? UInt32) ?? 1
        guard orientation != 1 else { return cg } // already upright — no work
        let oriented = CIImage(cgImage: cg).oriented(forExifOrientation: Int32(orientation))
        return context.createCGImage(oriented, from: oriented.extent) ?? cg
    }
}
#endif
