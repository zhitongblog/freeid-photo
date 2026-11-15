import Foundation
import FreeIDCore
#if canImport(CoreImage)
import CoreImage
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Turns a photo the user already has (from Photo Library or local History) into a spec-sized
/// export, and re-exports on demand when the user switches spec, background color, or retouch
/// sliders on the result screen.
final class PhotoImporter: @unchecked Sendable {

    struct Outcome: Sendable {
        /// The spec-sized JPEG, ready to save or share.
        let data: Data
        /// Upright source JPEG suitable for persisting in `PhotoHistoryStore`.
        let sourceJPEG: Data
        /// Raw full-frame measurements of the source image.
        let metrics: FaceMetrics
        /// How the result measures up, evaluated through the crop the export applied.
        let report: ComplianceReport
    }

    enum ImportError: Error, Sendable {
        case decodeFailed
        case analysisFailed(String)
        case noFace
        case multipleFaces
        case exportFailed
    }

    #if canImport(CoreImage) && os(iOS)
    private let queue = DispatchQueue(label: "freeid.import")
    private let engine = VisionComplianceEngine()
    private let pipeline = ExportPipeline()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private var lastSource: CGImage?
    private var lastMetrics: FaceMetrics?

    func load(
        _ fileData: Data,
        spec: PhotoSpec,
        backgroundHex: String?,
        brightnessBoost: Double = 0,
        skinSmoothing: Double = 0,
        metricsOverride: FaceMetrics? = nil,
        completion: @escaping @Sendable (Result<Outcome, ImportError>) -> Void
    ) {
        queue.async { [self] in
            guard let cg = ImageLoading.uprightCGImage(from: fileData, context: ciContext) else {
                completion(.failure(.decodeFailed)); return
            }
            let metrics: FaceMetrics
            if let metricsOverride {
                // Reconcile dimensions in case the stored JPEG was downscaled for history.
                metrics = FaceMetrics(
                    imageWidth: cg.width, imageHeight: cg.height, faceCount: metricsOverride.faceCount,
                    crownY: metricsOverride.crownY, chinY: metricsOverride.chinY,
                    eyeLineY: metricsOverride.eyeLineY, faceCenterX: metricsOverride.faceCenterX,
                    rollDegrees: metricsOverride.rollDegrees, yawDegrees: metricsOverride.yawDegrees,
                    pitchDegrees: metricsOverride.pitchDegrees,
                    eyesOpen: metricsOverride.eyesOpen, mouthClosed: metricsOverride.mouthClosed,
                    neutralExpression: metricsOverride.neutralExpression,
                    backgroundUniformity: metricsOverride.backgroundUniformity,
                    backgroundMeanHex: metricsOverride.backgroundMeanHex,
                    glassesDetected: metricsOverride.glassesDetected,
                    glareOnGlasses: metricsOverride.glareOnGlasses,
                    brightness: metricsOverride.brightness,
                    lightingUniformity: metricsOverride.lightingUniformity)
            } else {
                do { metrics = try engine.metrics(from: cg) }
                catch { completion(.failure(.analysisFailed(String(describing: error)))); return }
            }
            guard metrics.faceCount != 0 else { completion(.failure(.noFace)); return }
            guard metrics.faceCount == 1 else { completion(.failure(.multipleFaces)); return }

            lastSource = cg
            lastMetrics = metrics
            guard let data = exportData(cg, metrics, spec, backgroundHex, brightnessBoost, skinSmoothing) else {
                completion(.failure(.exportFailed)); return
            }
            let srcJPEG = historyJPEG(from: cg) ?? fileData
            let framed = ExportGeometry.reprojected(metrics, spec: spec)
            let report = SpecValidator.validate(framed, against: spec)
            completion(.success(Outcome(data: data, sourceJPEG: srcJPEG, metrics: metrics, report: report)))
        }
    }

    /// Re-export the imported photo for `targetSpec`, background color, and retouch sliders,
    /// returning both the new JPEG and the refreshed `ComplianceReport` for `targetSpec`.
    func reexport(
        spec targetSpec: PhotoSpec,
        backgroundHex: String?,
        brightnessBoost: Double = 0,
        skinSmoothing: Double = 0,
        completion: @escaping @Sendable ((data: Data, report: ComplianceReport)?) -> Void
    ) {
        queue.async { [self] in
            guard let cg = lastSource, let metrics = lastMetrics,
                  let data = exportData(cg, metrics, targetSpec, backgroundHex, brightnessBoost, skinSmoothing) else {
                completion(nil); return
            }
            let framed = ExportGeometry.reprojected(metrics, spec: targetSpec)
            let report = SpecValidator.validate(framed, against: targetSpec)
            completion((data, report))
        }
    }

    /// Render the print sheet for the imported photo.
    func printSheet(
        spec targetSpec: PhotoSpec,
        paper: ExportPipeline.PrintPaper,
        backgroundHex: String?,
        brightnessBoost: Double = 0,
        skinSmoothing: Double = 0,
        completion: @escaping @Sendable (Data?) -> Void
    ) {
        queue.async { [self] in
            guard let cg = lastSource, let metrics = lastMetrics else {
                completion(nil); return
            }
            completion(sheetData(cg, metrics, targetSpec, backgroundHex, brightnessBoost, skinSmoothing, paper))
        }
    }

    private func exportData(
        _ cg: CGImage, _ metrics: FaceMetrics, _ spec: PhotoSpec,
        _ backgroundHex: String?, _ brightnessBoost: Double, _ skinSmoothing: Double
    ) -> Data? {
        let opts = ExportPipeline.Options(
            replaceBackground: spec.digitalEditPolicy == .allowed,
            backgroundHex: backgroundHex,
            brightnessBoost: brightnessBoost,
            skinSmoothing: skinSmoothing)
        guard let out = try? pipeline.export(image: cg, spec: spec, metrics: metrics, options: opts) else {
            return nil
        }
        return try? pipeline.jpegData(out, spec: spec)
    }

    private func sheetData(
        _ cg: CGImage, _ metrics: FaceMetrics, _ spec: PhotoSpec,
        _ backgroundHex: String?, _ brightnessBoost: Double, _ skinSmoothing: Double,
        _ paper: ExportPipeline.PrintPaper
    ) -> Data? {
        let opts = ExportPipeline.Options(
            replaceBackground: spec.digitalEditPolicy == .allowed,
            backgroundHex: backgroundHex,
            brightnessBoost: brightnessBoost,
            skinSmoothing: skinSmoothing)
        guard let photo = try? pipeline.export(image: cg, spec: spec, metrics: metrics, options: opts),
              let sheet = pipeline.printSheet(photo: photo, spec: spec, paper: paper) else { return nil }
        return try? pipeline.jpegData(sheet.image, dpi: spec.dpi)
    }

    private func historyJPEG(from cg: CGImage) -> Data? {
        let maxDim = 2000.0
        let w = Double(cg.width), h = Double(cg.height)
        let target: CGImage
        if max(w, h) > maxDim {
            let s = maxDim / max(w, h)
            let ci = CIImage(cgImage: cg).transformed(by: CGAffineTransform(scaleX: s, y: s))
            target = ciContext.createCGImage(ci, from: ci.extent) ?? cg
        } else {
            target = cg
        }
        return try? pipeline.jpegData(target, quality: 0.90)
    }
    #else
    func load(_ fileData: Data, spec: PhotoSpec, backgroundHex: String?,
              brightnessBoost: Double = 0, skinSmoothing: Double = 0,
              metricsOverride: FaceMetrics? = nil,
              completion: @escaping @Sendable (Result<Outcome, ImportError>) -> Void) {
        completion(.failure(.decodeFailed))
    }
    func reexport(spec targetSpec: PhotoSpec, backgroundHex: String?,
                  brightnessBoost: Double = 0, skinSmoothing: Double = 0,
                  completion: @escaping @Sendable ((data: Data, report: ComplianceReport)?) -> Void) {
        completion(nil)
    }
    func printSheet(spec targetSpec: PhotoSpec, paper: ExportPipeline.PrintPaper, backgroundHex: String?,
                    brightnessBoost: Double = 0, skinSmoothing: Double = 0,
                    completion: @escaping @Sendable (Data?) -> Void) {
        completion(nil)
    }
    #endif
}
