#if canImport(CoreImage) && canImport(Vision)
import Foundation
import CoreImage
import CoreGraphics
import Vision
import ImageIO
import UniformTypeIdentifiers

/// Turns a captured photo into a spec-compliant output image: crop + align to the spec's
/// head/eye geometry, optional background replacement (only when the spec's edit policy
/// allows it), resize to the exact pixel dimensions, and optionally lay copies onto a
/// print sheet. All on-device, all Core Image.
public struct ExportPipeline: Sendable {

    public init() {}

    public enum ExportError: Error, CustomStringConvertible {
        case renderFailed
        case backgroundForbidden
        case encodeFailed
        public var description: String {
            switch self {
            case .renderFailed: return "image render failed"
            case .backgroundForbidden: return "this spec forbids digital background replacement"
            case .encodeFailed: return "image encoding failed"
            }
        }
    }

    public struct Options: Sendable {
        /// Replace the background with a solid color. Rejected for `.strict` specs.
        public var replaceBackground: Bool
        /// Background color as #RRGGBB to composite behind the subject. When nil, the spec's
        /// own `background.hex` is used. Lets the user pick white / blue / red / gray.
        public var backgroundHex: String?
        public init(replaceBackground: Bool = false, backgroundHex: String? = nil) {
            self.replaceBackground = replaceBackground
            self.backgroundHex = backgroundHex
        }
    }

    private let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Produce the final, spec-sized photo from a source image and its metrics.
    public func export(
        image cg: CGImage, spec: PhotoSpec, metrics: FaceMetrics, options: Options = .init()
    ) throws -> CGImage {
        if options.replaceBackground && spec.digitalEditPolicy == .strict {
            throw ExportError.backgroundForbidden
        }

        // 1. Crop to the spec's framing.
        let rect = ExportGeometry.cropRect(
            imageWidth: cg.width, imageHeight: cg.height, spec: spec, metrics: metrics)
        // CIImage origin is bottom-left; convert the top-left crop rect.
        let ci = CIImage(cgImage: cg)
        let ciCrop = CGRect(
            x: rect.x, y: Double(cg.height) - rect.y - rect.height,
            width: rect.width, height: rect.height)
        var working = ci.cropped(to: ciCrop)
        working = working.transformed(by: CGAffineTransform(
            translationX: -working.extent.origin.x, y: -working.extent.origin.y))

        // 2. Optional background replacement (user-chosen color, else the spec's default).
        if options.replaceBackground, let baseCG = render(working) {
            working = try replaceBackground(of: baseCG, with: options.backgroundHex ?? spec.background.hex)
        }

        // 3. Resize to exact spec pixels.
        let targetW = Double(spec.pixelWidth), targetH = Double(spec.pixelHeight)
        let sx = targetW / working.extent.width, sy = targetH / working.extent.height
        working = working.transformed(by: CGAffineTransform(scaleX: sx, y: sy))

        guard let out = context.createCGImage(
            working, from: CGRect(x: 0, y: 0, width: targetW, height: targetH)) else {
            throw ExportError.renderFailed
        }
        return out
    }

    /// Composite the foreground person over a solid background color using person
    /// segmentation. Used only when the spec allows digital editing.
    public func replaceBackground(of cg: CGImage, with hex: String) throws -> CIImage {
        let ci = CIImage(cgImage: cg)
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        let req = VNGeneratePersonSegmentationRequest()
        req.qualityLevel = .accurate
        req.outputPixelFormat = kCVPixelFormatType_OneComponent8
        try handler.perform([req])
        guard let mask = req.results?.first?.pixelBuffer else { return ci }

        var maskCI = CIImage(cvPixelBuffer: mask)
        // Scale the mask to the image size.
        let s = CGAffineTransform(
            scaleX: ci.extent.width / maskCI.extent.width,
            y: ci.extent.height / maskCI.extent.height)
        maskCI = maskCI.transformed(by: s)

        let rgb = ColorMath.rgb(fromHex: hex) ?? .init(r: 1, g: 1, b: 1)
        let bg = CIImage(color: CIColor(red: rgb.r, green: rgb.g, blue: rgb.b))
            .cropped(to: ci.extent)

        let blend = CIFilter(name: "CIBlendWithMask")!
        blend.setValue(ci, forKey: kCIInputImageKey)
        blend.setValue(bg, forKey: kCIInputBackgroundImageKey)
        blend.setValue(maskCI, forKey: kCIInputMaskImageKey)
        return blend.outputImage ?? ci
    }

    /// Lay multiple copies of the photo onto a print sheet at the spec's DPI.
    /// `paperWidthMM`/`paperHeightMM` default to a 6x4 inch print.
    public func printSheet(
        photo: CGImage, spec: PhotoSpec,
        paperWidthMM: Double = 152.4, paperHeightMM: Double = 101.6, marginMM: Double = 3
    ) -> CGImage? {
        let dpi = Double(spec.dpi)
        let pxPerMM = dpi / 25.4
        let sheetW = Int((paperWidthMM * pxPerMM).rounded())
        let sheetH = Int((paperHeightMM * pxPerMM).rounded())
        let cellW = spec.pixelWidth, cellH = spec.pixelHeight
        let gap = Int((marginMM * pxPerMM).rounded())

        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: sheetW, height: sheetH, bitsPerComponent: 8,
            bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))

        let cols = max(1, (sheetW + gap) / (cellW + gap))
        let rows = max(1, (sheetH + gap) / (cellH + gap))
        for r in 0..<rows {
            for c in 0..<cols {
                let x = gap + c * (cellW + gap)
                let y = gap + r * (cellH + gap)
                ctx.draw(photo, in: CGRect(x: x, y: y, width: cellW, height: cellH))
            }
        }
        return ctx.makeImage()
    }

    // MARK: - Encoding

    public func jpegData(_ cg: CGImage, quality: Double = 0.95) throws -> Data {
        try encode(cg, type: UTType.jpeg.identifier,
                   properties: [kCGImageDestinationLossyCompressionQuality: quality])
    }
    public func pngData(_ cg: CGImage) throws -> Data {
        try encode(cg, type: UTType.png.identifier, properties: [:])
    }

    private func encode(_ cg: CGImage, type: String, properties: [CFString: Any]) throws -> Data {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, type as CFString, 1, nil) else {
            throw ExportError.encodeFailed
        }
        CGImageDestinationAddImage(dest, cg, properties as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ExportError.encodeFailed }
        return data as Data
    }

    private func render(_ ci: CIImage) -> CGImage? {
        context.createCGImage(ci, from: ci.extent)
    }
}
#endif
