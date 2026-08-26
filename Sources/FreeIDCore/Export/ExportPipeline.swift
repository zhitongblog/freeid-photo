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
        let targetW = spec.pixelWidth, targetH = spec.pixelHeight

        // Background-replaced path: replace the background on the WHOLE source, then place it on
        // a color canvas using the IDEAL (unclamped) crop. Areas the source doesn't cover are
        // filled with the same background color — that's what gives proper top/bottom/side
        // whitespace even when the source is a tight headshot.
        if options.replaceBackground {
            let hex = options.backgroundHex ?? spec.background.hex
            let replaced = try replaceBackground(of: cg, with: hex)
            guard let baseCG = context.createCGImage(replaced, from: replaced.extent) else {
                throw ExportError.renderFailed
            }
            let rect = ExportGeometry.idealCropRect(
                imageWidth: cg.width, imageHeight: cg.height, spec: spec, metrics: metrics)
            guard let out = compose(baseCG, crop: rect, targetW: targetW, targetH: targetH, hex: hex) else {
                throw ExportError.renderFailed
            }
            return out
        }

        // Strict path (no editing): crop clamped to the source, resize only. No padding —
        // we can't fabricate background where the real photo didn't reach.
        let rect = ExportGeometry.cropRect(
            imageWidth: cg.width, imageHeight: cg.height, spec: spec, metrics: metrics)
        let ci = CIImage(cgImage: cg)
        let ciCrop = CGRect(
            x: rect.x, y: Double(cg.height) - rect.y - rect.height,
            width: rect.width, height: rect.height)
        var working = ci.cropped(to: ciCrop)
        working = working.transformed(by: CGAffineTransform(
            translationX: -working.extent.origin.x, y: -working.extent.origin.y))
        let sx = Double(targetW) / working.extent.width, sy = Double(targetH) / working.extent.height
        working = working.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
        guard let out = context.createCGImage(
            working, from: CGRect(x: 0, y: 0, width: Double(targetW), height: Double(targetH))) else {
            throw ExportError.renderFailed
        }
        return out
    }

    /// Draw `src` onto a `hex`-filled `targetW×targetH` canvas so the (possibly out-of-bounds)
    /// crop rect maps to the full output; uncovered areas stay the background color.
    private func compose(_ src: CGImage, crop rect: ExportGeometry.PixelRect,
                         targetW: Int, targetH: Int, hex: String) -> CGImage? {
        let scale = Double(targetW) / rect.width
        let W = Double(src.width), H = Double(src.height)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: targetW, height: targetH, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let rgb = ColorMath.rgb(fromHex: hex) ?? .init(r: 1, g: 1, b: 1)
        ctx.setFillColor(CGColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: targetW, height: targetH))
        // CGContext is bottom-left; rect is top-left. Place the whole source scaled so the crop
        // window lands on the output: crop bottom-left = (rect.x, H - rect.y - rect.height).
        let drawRect = CGRect(x: -rect.x * scale,
                              y: -(H - rect.y - rect.height) * scale,
                              width: W * scale, height: H * scale)
        ctx.interpolationQuality = .high
        ctx.draw(src, in: drawRect)
        return ctx.makeImage()
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

    /// Papers a photo sheet can be laid out on. The two imperial sizes are what every
    /// drugstore/photo-lab print counter accepts (Walgreens, CVS, 沖印店); A4 is for
    /// printing at home or at an office printer.
    public enum PrintPaper: String, CaseIterable, Sendable {
        case fourBySix, fiveBySeven, a4

        /// Millimetres, in the orientation the sheet is laid out in.
        public var sizeMM: (width: Double, height: Double) {
            switch self {
            case .fourBySix:   return (152.4, 101.6)   // 6×4 in, landscape
            case .fiveBySeven: return (177.8, 127.0)   // 7×5 in, landscape
            case .a4:          return (210.0, 297.0)   // A4, portrait
            }
        }
    }

    /// Lay copies of `photo` onto `paper` at the spec's DPI, and report how many fit.
    /// Returns nil if the sheet can't be rendered.
    public func printSheet(
        photo: CGImage, spec: PhotoSpec, paper: PrintPaper, marginMM: Double = 3
    ) -> (image: CGImage, copies: Int)? {
        let size = paper.sizeMM
        guard let sheet = printSheet(photo: photo, spec: spec,
                                     paperWidthMM: size.width, paperHeightMM: size.height,
                                     marginMM: marginMM) else { return nil }
        return (sheet, copiesPerSheet(spec: spec, paper: paper, marginMM: marginMM))
    }

    /// How many spec-sized photos fit on `paper`. Same tiling math as `printSheet`, kept
    /// pure so the UI can show the count before spending time rendering the sheet.
    public func copiesPerSheet(spec: PhotoSpec, paper: PrintPaper, marginMM: Double = 3) -> Int {
        let size = paper.sizeMM
        let pxPerMM = Double(spec.dpi) / 25.4
        let sheetW = Int((size.width * pxPerMM).rounded())
        let sheetH = Int((size.height * pxPerMM).rounded())
        let gap = Int((marginMM * pxPerMM).rounded())
        let cols = max(1, (sheetW + gap) / (spec.pixelWidth + gap))
        let rows = max(1, (sheetH + gap) / (spec.pixelHeight + gap))
        return cols * rows
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

        // Centre the block of photos. Laying it out from one corner piles all the leftover
        // paper onto the opposite two edges, which is harder to cut and reads as a mistake.
        let usedW = cols * cellW + (cols - 1) * gap
        let usedH = rows * cellH + (rows - 1) * gap
        let originX = max(0, (sheetW - usedW) / 2)
        let originY = max(0, (sheetH - usedH) / 2)

        ctx.setStrokeColor(CGColor(red: 0.72, green: 0.72, blue: 0.72, alpha: 1))
        ctx.setLineWidth(1)
        for r in 0..<rows {
            for c in 0..<cols {
                let cell = CGRect(x: originX + c * (cellW + gap), y: originY + r * (cellH + gap),
                                  width: cellW, height: cellH)
                ctx.draw(photo, in: cell)
                // A hairline just outside each photo: a white-background ID photo on white
                // paper has no visible edge, and you can't cut what you can't see.
                ctx.stroke(cell.insetBy(dx: -0.5, dy: -0.5))
            }
        }
        return ctx.makeImage()
    }

    // MARK: - Encoding

    /// Encode as JPEG. Pass `dpi` to stamp the resolution into the file — print shops and
    /// AirPrint size the paper from it, so a sheet without it can come out scaled wrong.
    public func jpegData(_ cg: CGImage, quality: Double = 0.95, dpi: Int? = nil) throws -> Data {
        var props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        if let dpi {
            props[kCGImagePropertyDPIWidth] = dpi
            props[kCGImagePropertyDPIHeight] = dpi
        }
        return try encode(cg, type: UTType.jpeg.identifier, properties: props)
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
