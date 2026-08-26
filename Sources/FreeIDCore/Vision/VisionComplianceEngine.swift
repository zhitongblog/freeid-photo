#if canImport(Vision) && canImport(CoreImage)
import Foundation
import Vision
import CoreImage
import CoreGraphics

/// Produces FaceMetrics from a real image using Apple Vision (face landmarks + pose)
/// and person segmentation (background color/uniformity). This is the only place that
/// touches Vision; it hands raw observations to FaceMetricsMath for the pure conversion.
///
///   CGImage ──VNDetectFaceLandmarksRequest──▶ box, landmarks, roll/yaw/pitch
///           ──VNGeneratePersonSegmentationRequest──▶ person mask ──▶ background stats
///           ──downscaled bitmap──▶ brightness
///                       └────────────▶ FaceMetricsMath.build ──▶ FaceMetrics
///
/// Known v1 limitations (documented, not hidden): crown/hairline is estimated from the
/// face box; glasses/glare detection is not yet wired (reported false); "neutral
/// expression" defaults to true. These are calibrated/added against real device photos.
public struct VisionComplianceEngine: Sendable {

    public init() {}

    public enum EngineError: Error, CustomStringConvertible {
        case requestFailed(String)
        case cannotReadPixels
        public var description: String {
            switch self {
            case .requestFailed(let s): return "Vision request failed: \(s)"
            case .cannotReadPixels: return "could not read image pixels"
            }
        }
    }

    /// Analyze `cgImage` and return FaceMetrics. If no face is found, returns metrics
    /// with `faceCount == 0` (every face-dependent field zeroed) so the validator can
    /// report "no face detected" rather than crashing.
    public func metrics(from cgImage: CGImage) throws -> FaceMetrics {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        let faceReq = VNDetectFaceLandmarksRequest()
        let segReq = VNGeneratePersonSegmentationRequest()
        segReq.qualityLevel = .balanced
        segReq.outputPixelFormat = kCVPixelFormatType_OneComponent8

        // Perform the two requests SEPARATELY. Face landmarks are essential; person
        // segmentation only sharpens the background statistics. Batching them means one
        // unavailable request discards both results — on the Simulator, where segmentation
        // reports "E5RT is not supported", that turned every photo into "can't read this
        // photo" even though the face was perfectly detectable.
        do { try handler.perform([faceReq]) }
        catch { throw EngineError.requestFailed(String(describing: error)) }

        // A separate handler: a handler that already threw can't be reused reliably.
        let mask: CVPixelBuffer? = {
            let segHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            guard (try? segHandler.perform([segReq])) != nil else { return nil }
            return segReq.results?.first?.pixelBuffer
        }()

        let faces = faceReq.results ?? []
        let bitmap = try Bitmap(cgImage: cgImage, maxDimension: 96)
        let bg = backgroundStats(bitmap: bitmap, mask: mask)
        let brightness = bitmap.meanLuminance()

        guard let face = largestFace(faces) else {
            return FaceMetrics(
                imageWidth: cgImage.width, imageHeight: cgImage.height, faceCount: 0,
                crownY: 0, chinY: 0, eyeLineY: 0, faceCenterX: 0.5,
                rollDegrees: 0, yawDegrees: 0, pitchDegrees: 0,
                eyesOpen: false, mouthClosed: false, neutralExpression: false,
                backgroundUniformity: bg.uniformity, backgroundMeanHex: bg.hex,
                glassesDetected: false, glareOnGlasses: false, brightness: brightness)
        }

        let box = face.boundingBox // normalized, bottom-left
        let lm = face.landmarks

        let leftEye = eyeCenter(lm?.leftPupil, fallback: lm?.leftEye, in: box)
            ?? FaceMetricsMath.NormPoint(x: box.midX, y: box.midY)
        let rightEye = eyeCenter(lm?.rightPupil, fallback: lm?.rightEye, in: box)
            ?? FaceMetricsMath.NormPoint(x: box.midX, y: box.midY)
        let chinVisionY = lowestContourY(lm?.faceContour, in: box) ?? box.minY

        let inputs = FaceMetricsMath.Inputs(
            faceCount: faces.count,
            imageWidth: cgImage.width, imageHeight: cgImage.height,
            faceBoundingBox: .init(x: box.minX, y: box.minY, w: box.width, h: box.height),
            chinVisionY: chinVisionY,
            leftEye: leftEye, rightEye: rightEye,
            rollDegrees: degrees(face.roll), yawDegrees: degrees(face.yaw), pitchDegrees: degrees(face.pitch),
            eyeAspectRatio: eyeAspectRatio(lm?.leftEye, lm?.rightEye, box: box),
            lipGapRatio: lipGapRatio(lm?.innerLips, box: box),
            backgroundUniformity: bg.uniformity, backgroundMeanHex: bg.hex,
            glassesDetected: false, glareOnGlasses: false,
            brightness: brightness, neutralExpression: true)

        return FaceMetricsMath.build(inputs)
    }

    // MARK: - Vision helpers

    private func largestFace(_ faces: [VNFaceObservation]) -> VNFaceObservation? {
        faces.max { a, b in (a.boundingBox.width * a.boundingBox.height) < (b.boundingBox.width * b.boundingBox.height) }
    }

    private func degrees(_ radians: NSNumber?) -> Double {
        guard let r = radians?.doubleValue else { return 0 }
        return r * 180 / .pi
    }

    /// Center of a landmark region in image-normalized Vision coords (bottom-left).
    private func eyeCenter(_ primary: VNFaceLandmarkRegion2D?, fallback: VNFaceLandmarkRegion2D?,
                           in box: CGRect) -> FaceMetricsMath.NormPoint? {
        let region = primary ?? fallback
        guard let pts = region?.normalizedPoints, !pts.isEmpty else { return nil }
        let cx = pts.map { Double($0.x) }.reduce(0, +) / Double(pts.count)
        let cy = pts.map { Double($0.y) }.reduce(0, +) / Double(pts.count)
        return FaceMetricsMath.NormPoint(
            x: Double(box.minX) + cx * Double(box.width),
            y: Double(box.minY) + cy * Double(box.height))
    }

    private func lowestContourY(_ contour: VNFaceLandmarkRegion2D?, in box: CGRect) -> Double? {
        guard let pts = contour?.normalizedPoints, !pts.isEmpty else { return nil }
        let minLocalY = pts.map { Double($0.y) }.min() ?? 0
        return Double(box.minY) + minLocalY * Double(box.height)
    }

    /// Eye aspect ratio = mean(eye height) / mean(eye width). Low ≈ closed.
    private func eyeAspectRatio(_ left: VNFaceLandmarkRegion2D?, _ right: VNFaceLandmarkRegion2D?,
                                box: CGRect) -> Double {
        func ear(_ r: VNFaceLandmarkRegion2D?) -> Double? {
            guard let p = r?.normalizedPoints, p.count >= 4 else { return nil }
            let xs = p.map { Double($0.x) }, ys = p.map { Double($0.y) }
            let w = (xs.max()! - xs.min()!), h = (ys.max()! - ys.min()!)
            return w > 0 ? h / w : nil
        }
        let vals = [ear(left), ear(right)].compactMap { $0 }
        return vals.isEmpty ? 0.3 : vals.reduce(0, +) / Double(vals.count)
    }

    /// Inner-lip vertical gap / mouth width. High ≈ open mouth.
    private func lipGapRatio(_ innerLips: VNFaceLandmarkRegion2D?, box: CGRect) -> Double {
        guard let p = innerLips?.normalizedPoints, p.count >= 4 else { return 0 }
        let xs = p.map { Double($0.x) }, ys = p.map { Double($0.y) }
        let w = (xs.max()! - xs.min()!), h = (ys.max()! - ys.min()!)
        return w > 0 ? h / w : 0
    }

    // MARK: - Background stats

    private func backgroundStats(bitmap: Bitmap, mask: CVPixelBuffer?) -> (hex: String, uniformity: Double) {
        var rs: [Double] = [], gs: [Double] = [], bs: [Double] = [], lums: [Double] = []

        let maskReader = mask.map { MaskReader($0) }
        maskReader?.lock(); defer { maskReader?.unlock() }

        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                let u = (Double(x) + 0.5) / Double(bitmap.width)
                let v = (Double(y) + 0.5) / Double(bitmap.height)
                // person mask value high = person; treat low as background
                let personConfidence = maskReader?.sample(u: u, v: v) ?? 0
                if personConfidence >= 0.5 { continue }
                let px = bitmap.pixel(x: x, y: y)
                rs.append(px.r); gs.append(px.g); bs.append(px.b)
                lums.append(0.2126 * px.r + 0.7152 * px.g + 0.0722 * px.b)
            }
        }
        guard !rs.isEmpty else { return ("#000000", 0) }
        let mr = rs.reduce(0,+)/Double(rs.count)
        let mg = gs.reduce(0,+)/Double(gs.count)
        let mb = bs.reduce(0,+)/Double(bs.count)
        let ml = lums.reduce(0,+)/Double(lums.count)
        let variance = lums.reduce(0) { $0 + ($1 - ml) * ($1 - ml) } / Double(lums.count)
        let stddev = variance.squareRoot()
        // stddev 0 = perfectly uniform → 1.0; scale so ~0.2 stddev maps to 0.
        let uniformity = max(0, 1 - stddev / 0.2)
        let hex = String(format: "#%02X%02X%02X",
                         Int((mr*255).rounded()), Int((mg*255).rounded()), Int((mb*255).rounded()))
        return (hex, uniformity)
    }
}

// MARK: - Small pixel utilities

/// A downscaled RGBA8 snapshot of a CGImage, for cheap pixel statistics.
struct Bitmap {
    let width: Int
    let height: Int
    private let data: [UInt8] // RGBA, row-major, top-left origin

    struct Pixel { let r, g, b: Double } // 0..1

    init(cgImage: CGImage, maxDimension: Int) throws {
        let srcW = cgImage.width, srcH = cgImage.height
        let scale = Double(maxDimension) / Double(max(srcW, srcH))
        let w = max(1, Int(Double(srcW) * scale)), h = max(1, Int(Double(srcH) * scale))
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw VisionComplianceEngine.EngineError.cannotReadPixels
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        self.width = w; self.height = h; self.data = buf
    }

    func pixel(x: Int, y: Int) -> Pixel {
        let i = (y * width + x) * 4
        return Pixel(r: Double(data[i]) / 255, g: Double(data[i+1]) / 255, b: Double(data[i+2]) / 255)
    }

    func meanLuminance() -> Double {
        guard width * height > 0 else { return 0 }
        var sum = 0.0
        for y in 0..<height { for x in 0..<width {
            let p = pixel(x: x, y: y)
            sum += 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b
        } }
        return sum / Double(width * height)
    }
}

/// Reads a OneComponent8 person-segmentation mask by normalized coordinate.
final class MaskReader {
    private let pb: CVPixelBuffer
    private var base: UnsafeMutableRawPointer?
    private var w = 0, h = 0, stride = 0
    init(_ pb: CVPixelBuffer) { self.pb = pb }
    func lock() {
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        base = CVPixelBufferGetBaseAddress(pb)
        w = CVPixelBufferGetWidth(pb); h = CVPixelBufferGetHeight(pb)
        stride = CVPixelBufferGetBytesPerRow(pb)
    }
    func unlock() { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
    /// u,v in 0..1, top-left origin. Returns person confidence 0..1.
    func sample(u: Double, v: Double) -> Double {
        guard let base, w > 0, h > 0 else { return 0 }
        let x = min(w - 1, max(0, Int(u * Double(w))))
        let y = min(h - 1, max(0, Int(v * Double(h))))
        let p = base.advanced(by: y * stride + x).assumingMemoryBound(to: UInt8.self)
        return Double(p.pointee) / 255.0
    }
}
#endif
