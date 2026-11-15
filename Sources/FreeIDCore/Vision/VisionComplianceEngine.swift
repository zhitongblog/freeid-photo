#if canImport(Vision) && canImport(CoreImage)
import Foundation
import Vision
import CoreImage
import CoreGraphics

/// Produces FaceMetrics from a real image using Apple Vision (face landmarks + pose),
/// person segmentation (crown + background color/uniformity), and periocular/cheek pixel
/// statistics (glasses/glare, facial lighting balance, smile expression).
///
///   CGImage ──VNDetectFaceLandmarksRequest──▶ box, landmarks, roll/yaw/pitch, smile
///           ──VNGeneratePersonSegmentationRequest──▶ person mask ──▶ crown + background stats
///           ──downscaled bitmap + face crop──▶ brightness, cheek symmetry, glasses & glare
///                       └────────────▶ FaceMetricsMath.build ──▶ FaceMetrics
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
                glassesDetected: false, glareOnGlasses: false, brightness: brightness,
                lightingUniformity: 1.0)
        }

        let box = face.boundingBox // normalized, bottom-left
        let lm = face.landmarks

        let leftEye = eyeCenter(lm?.leftPupil, fallback: lm?.leftEye, in: box)
            ?? FaceMetricsMath.NormPoint(x: box.midX - box.width * 0.16, y: box.midY + box.height * 0.1)
        let rightEye = eyeCenter(lm?.rightPupil, fallback: lm?.rightEye, in: box)
            ?? FaceMetricsMath.NormPoint(x: box.midX + box.width * 0.16, y: box.midY + box.height * 0.1)
        let chinVisionY = lowestContourY(lm?.faceContour, in: box) ?? box.minY
        let measuredCrown = measureCrownVisionY(mask: mask, faceBox: box)
        let lipGap = lipGapRatio(lm?.innerLips, box: box)
        let smile = smileScore(outerLips: lm?.outerLips, box: box, lipGapRatio: lipGap)
        let lightingUni = measureCheekLighting(
            bitmap: bitmap, leftEye: leftEye, rightEye: rightEye, chinVisionY: chinVisionY)
        let glasses = detectGlassesAndGlare(
            cgImage: cgImage, leftEye: leftEye, rightEye: rightEye, faceBox: box)

        let inputs = FaceMetricsMath.Inputs(
            faceCount: faces.count,
            imageWidth: cgImage.width, imageHeight: cgImage.height,
            faceBoundingBox: .init(x: box.minX, y: box.minY, w: box.width, h: box.height),
            chinVisionY: chinVisionY,
            leftEye: leftEye, rightEye: rightEye,
            rollDegrees: degrees(face.roll), yawDegrees: degrees(face.yaw), pitchDegrees: degrees(face.pitch),
            eyeAspectRatio: eyeAspectRatio(lm?.leftEye, lm?.rightEye, box: box),
            lipGapRatio: lipGap,
            backgroundUniformity: bg.uniformity, backgroundMeanHex: bg.hex,
            glassesDetected: glasses.glassesDetected, glareOnGlasses: glasses.glareOnGlasses,
            brightness: brightness, neutralExpression: true,
            measuredCrownVisionY: measuredCrown,
            smileScore: smile,
            lightingUniformity: lightingUni)

        return FaceMetricsMath.build(inputs)
    }

    // MARK: - Vision helpers

    /// Scan the person-segmentation mask within the central horizontal band of the face box
    /// from the top of the image downward to locate the true top of the hair/crown.
    /// Returns a Vision bottom-left Y coordinate (0..1), or nil if no mask is available.
    private func measureCrownVisionY(mask: CVPixelBuffer?, faceBox box: CGRect) -> Double? {
        guard let mask else { return nil }
        let reader = MaskReader(mask)
        reader.lock(); defer { reader.unlock() }
        // Sample the middle 60% of the face width so stray shoulder/background artifacts at
        // the far edges don't register as the crown.
        let minU = Double(box.minX + box.width * 0.20)
        let maxU = Double(box.maxX - box.width * 0.20)
        guard maxU > minU else { return nil }
        let maxV = max(0.0, 1.0 - Double(box.maxY)) // stop at the top of the Vision face box
        let stepsV = 120
        let stepsU = 9
        for iv in 0...stepsV {
            let v = Double(iv) / Double(stepsV) * maxV
            var hits = 0
            for iu in 0..<stepsU {
                let u = minU + (maxU - minU) * Double(iu) / Double(stepsU - 1)
                if reader.sample(u: u, v: v) >= 0.55 {
                    hits += 1
                }
            }
            // Require at least 2 sample columns to agree so a single noisy pixel doesn't trigger.
            if hits >= 2 {
                return 1.0 - v
            }
        }
        return nil
    }

    /// Measure mouth corner lift relative to central lip midline from `outerLips` landmarks.
    private func smileScore(outerLips: VNFaceLandmarkRegion2D?, box: CGRect, lipGapRatio: Double) -> Double {
        guard let pts = outerLips?.normalizedPoints, pts.count >= 6 else { return 0 }
        let xs = pts.map { Double($0.x) }
        guard let minX = xs.min(), let maxX = xs.max(), maxX - minX > 0.02 else { return 0 }
        let width = maxX - minX
        let midX = (minX + maxX) / 2.0

        // Leftmost and rightmost lip corners vs. points near the horizontal midline.
        let leftPts = pts.filter { Double($0.x) <= minX + width * 0.14 }
        let rightPts = pts.filter { Double($0.x) >= maxX - width * 0.14 }
        let centerPts = pts.filter { abs(Double($0.x) - midX) <= width * 0.18 }
        guard !leftPts.isEmpty, !rightPts.isEmpty, !centerPts.isEmpty else { return 0 }

        let leftY = leftPts.map { Double($0.y) }.reduce(0, +) / Double(leftPts.count)
        let rightY = rightPts.map { Double($0.y) }.reduce(0, +) / Double(rightPts.count)
        let centerY = centerPts.map { Double($0.y) }.reduce(0, +) / Double(centerPts.count)

        return FaceMetricsMath.smileScore(
            leftCornerY: leftY, rightCornerY: rightY,
            mouthCenterY: centerY, mouthWidth: width, lipGapRatio: lipGapRatio)
    }

    /// Compare luminance on symmetric left and right cheek patches below the eyes to catch
    /// harsh side lighting ("阴阳脸").
    private func measureCheekLighting(
        bitmap: Bitmap,
        leftEye: FaceMetricsMath.NormPoint,
        rightEye: FaceMetricsMath.NormPoint,
        chinVisionY: Double
    ) -> Double {
        let e1x = min(leftEye.x, rightEye.x)
        let e2x = max(leftEye.x, rightEye.x)
        let eyeTopLeftY = 1.0 - (leftEye.y + rightEye.y) / 2.0
        let chinTopLeftY = 1.0 - chinVisionY
        let eyeToChin = max(0.04, chinTopLeftY - eyeTopLeftY)
        let io = max(0.03, e2x - e1x)

        // Mid-cheek sits ~38% of the way from eye line to chin, slightly inside the outer eye line.
        let cheekCenterY = eyeTopLeftY + eyeToChin * 0.38
        let halfH = eyeToChin * 0.12
        let halfW = io * 0.18

        let leftLum = bitmap.meanLuminance(
            minU: e1x - halfW * 0.7, maxU: e1x + halfW * 1.1,
            minV: cheekCenterY - halfH, maxV: cheekCenterY + halfH)
        let rightLum = bitmap.meanLuminance(
            minU: e2x - halfW * 1.1, maxU: e2x + halfW * 0.7,
            minV: cheekCenterY - halfH, maxV: cheekCenterY + halfH)

        guard let l = leftLum, let r = rightLum else { return 1.0 }
        return FaceMetricsMath.cheekLightingUniformity(leftMeanLum: l, rightMeanLum: r)
    }

    /// Inspect a crisp face-box crop around the nose bridge and periocular zones for eyeglass
    /// frames and specular lens glare.
    private func detectGlassesAndGlare(
        cgImage: CGImage,
        leftEye: FaceMetricsMath.NormPoint,
        rightEye: FaceMetricsMath.NormPoint,
        faceBox box: CGRect
    ) -> (glassesDetected: Bool, glareOnGlasses: Bool) {
        let imgW = Double(cgImage.width), imgH = Double(cgImage.height)
        guard imgW >= 64, imgH >= 64 else { return (false, false) }

        // Crop to the Vision face box (converted from bottom-left to top-left pixel coords).
        let cropX = max(0, Int((Double(box.minX) * imgW).rounded(.down)))
        let cropY = max(0, Int(((1.0 - Double(box.maxY)) * imgH).rounded(.down)))
        let cropW = min(cgImage.width - cropX, max(32, Int((Double(box.width) * imgW).rounded())))
        let cropH = min(cgImage.height - cropY, max(32, Int((Double(box.height) * imgH).rounded())))
        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
        guard let faceCG = cgImage.cropping(to: cropRect),
              let faceBmp = try? Bitmap(cgImage: faceCG, maxDimension: 220),
              faceBmp.width >= 32, faceBmp.height >= 32 else {
            return (false, false)
        }

        // Map eye centers into `faceBmp` pixel coordinates (top-left origin).
        func toBmp(_ pt: FaceMetricsMath.NormPoint) -> (x: Double, y: Double) {
            let pxX = (pt.x * imgW - Double(cropX)) / Double(cropW) * Double(faceBmp.width)
            let pxY = ((1.0 - pt.y) * imgH - Double(cropY)) / Double(cropH) * Double(faceBmp.height)
            return (pxX, pxY)
        }
        let p1 = toBmp(leftEye), p2 = toBmp(rightEye)
        let lx = min(p1.x, p2.x), rx = max(p1.x, p2.x)
        let eyeY = (p1.y + p2.y) / 2.0
        let io = rx - lx
        guard io >= 10 else { return (false, false) }

        // 1. Nose-bridge horizontal bar edge vs. lower-nose smooth skin baseline.
        let bridgeMidX = (lx + rx) / 2.0
        let bridgeGrad = faceBmp.verticalEdgeStrength(
            minX: Int(bridgeMidX - io * 0.12), maxX: Int(bridgeMidX + io * 0.12),
            minY: Int(eyeY - io * 0.14), maxY: Int(eyeY + io * 0.12), topQuartile: true)
        let noseSkinGrad = faceBmp.verticalEdgeStrength(
            minX: Int(bridgeMidX - io * 0.10), maxX: Int(bridgeMidX + io * 0.10),
            minY: Int(eyeY + io * 0.22), maxY: Int(eyeY + io * 0.40), topQuartile: false)
        let bridgeEdgeRatio = max(0, bridgeGrad - noseSkinGrad * 1.25)

        // 2. Lower lens rim zone (sits on upper cheek below lower eyelashes: 0.24..0.38 × io).
        let leftRim = faceBmp.verticalEdgeStrength(
            minX: Int(lx - io * 0.22), maxX: Int(lx + io * 0.22),
            minY: Int(eyeY + io * 0.24), maxY: Int(eyeY + io * 0.38), topQuartile: true)
        let rightRim = faceBmp.verticalEdgeStrength(
            minX: Int(rx - io * 0.22), maxX: Int(rx + io * 0.22),
            minY: Int(eyeY + io * 0.24), maxY: Int(eyeY + io * 0.38), topQuartile: true)
        let cheekSkinGrad = faceBmp.verticalEdgeStrength(
            minX: Int(lx - io * 0.18), maxX: Int(lx + io * 0.18),
            minY: Int(eyeY + io * 0.44), maxY: Int(eyeY + io * 0.56), topQuartile: false)
        let rimContrast = max(0, (leftRim + rightRim) / 2.0 - cheekSkinGrad * 1.25)

        // 3. Specular glare inside left & right lens boxes (excluding tiny pupil catchlights).
        var lensLums: [Double] = []
        for cx in [lx, rx] {
            let x0 = max(0, Int(cx - io * 0.32)), x1 = min(faceBmp.width - 1, Int(cx + io * 0.32))
            let y0 = max(0, Int(eyeY - io * 0.22)), y1 = min(faceBmp.height - 1, Int(eyeY + io * 0.24))
            guard x1 >= x0, y1 >= y0 else { continue }
            for y in y0...y1 {
                for x in x0...x1 {
                    // Skip central pupil catchlight (~0.07 × io radius) so natural eye sparkle isn't glare.
                    let dx = abs(Double(x) - cx), dy = abs(Double(y) - eyeY)
                    if dx < io * 0.08 && dy < io * 0.08 { continue }
                    lensLums.append(faceBmp.luminance(x: x, y: y))
                }
            }
        }

        var specFraction = 0.0
        var peakContrast = 0.0
        if lensLums.count >= 20 {
            let sorted = lensLums.sorted()
            let med = sorted[sorted.count / 2]
            let p98 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.985))]
            peakContrast = max(0, p98 - med)
            let brightCount = lensLums.filter { $0 >= 0.92 && ($0 - med) >= 0.24 }.count
            specFraction = Double(brightCount) / Double(lensLums.count)
        }

        return FaceMetricsMath.analyzeGlassesAndGlare(
            bridgeEdgeRatio: bridgeEdgeRatio,
            rimContrast: rimContrast,
            specularSpotFraction: specFraction,
            eyePeakContrast: peakContrast)
    }

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

    func luminance(x: Int, y: Int) -> Double {
        let p = pixel(x: x, y: y)
        return 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b
    }

    func meanLuminance() -> Double {
        guard width * height > 0 else { return 0 }
        var sum = 0.0
        for y in 0..<height { for x in 0..<width {
            sum += luminance(x: x, y: y)
        } }
        return sum / Double(width * height)
    }

    /// Mean luminance inside a normalized top-left rectangle `[minU..maxU, minV..maxV]`.
    func meanLuminance(minU: Double, maxU: Double, minV: Double, maxV: Double) -> Double? {
        let x0 = max(0, Int((minU * Double(width)).rounded(.down)))
        let x1 = min(width - 1, Int((maxU * Double(width)).rounded(.up)))
        let y0 = max(0, Int((minV * Double(height)).rounded(.down)))
        let y1 = min(height - 1, Int((maxV * Double(height)).rounded(.up)))
        guard x1 >= x0, y1 >= y0 else { return nil }
        var sum = 0.0
        var n = 0
        for y in y0...y1 {
            for x in x0...x1 {
                sum += luminance(x: x, y: y)
                n += 1
            }
        }
        return n > 0 ? sum / Double(n) : nil
    }

    /// Vertical gradient (`|lum(x, y+1) - lum(x, y-1)| / 2`) across rows in `[minY..maxY]`,
    /// responsive to horizontal structures like eyeglass bridges and lower rims.
    func verticalEdgeStrength(minX: Int, maxX: Int, minY: Int, maxY: Int, topQuartile: Bool) -> Double {
        let x0 = max(0, minX), x1 = min(width - 1, maxX)
        let y0 = max(1, minY), y1 = min(height - 2, maxY)
        guard x1 >= x0, y1 >= y0 else { return 0 }
        var rowMeans: [Double] = []
        for y in y0...y1 {
            var rowSum = 0.0
            for x in x0...x1 {
                rowSum += abs(luminance(x: x, y: y + 1) - luminance(x: x, y: y - 1)) * 0.5
            }
            rowMeans.append(rowSum / Double(x1 - x0 + 1))
        }
        guard !rowMeans.isEmpty else { return 0 }
        if topQuartile && rowMeans.count >= 4 {
            let sorted = rowMeans.sorted(by: >)
            let k = max(1, sorted.count / 4)
            return sorted.prefix(k).reduce(0, +) / Double(k)
        }
        return rowMeans.reduce(0, +) / Double(rowMeans.count)
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
