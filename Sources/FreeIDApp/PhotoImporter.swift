import Foundation
import FreeIDCore
#if canImport(CoreImage)
import CoreImage
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Turns a photo the user already has into a spec-sized export.
///
/// Mirrors `CameraController`'s still-capture path — upright decode → Vision metrics →
/// `ExportPipeline` — but starts from image bytes instead of the sensor. That covers the
/// cases the viewfinder can't: a baby who won't sit for a live capture, a shot a friend
/// took, a photo already in the camera roll.
///
/// Work runs on a private serial queue and only Sendable values cross back, matching the
/// concurrency shape of `CameraController`.
final class PhotoImporter: @unchecked Sendable {

    /// What an import produced: the finished photo, plus an honest verdict on it.
    struct Outcome: Sendable {
        /// The spec-sized JPEG, ready to save or share.
        let data: Data
        /// How the result measures up, evaluated through the crop the export applied.
        let report: ComplianceReport
    }

    enum ImportError: Error, Sendable {
        /// The bytes aren't an image we can decode.
        case decodeFailed
        /// Decoded fine, but Vision couldn't analyze it. Carries the underlying reason —
        /// the two look identical to the user but are very different to debug.
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

    /// The imported source and its measurements, kept so the result screen can switch
    /// background color without making the user pick the photo again.
    private var lastSource: CGImage?
    private var lastMetrics: FaceMetrics?
    private var lastSpec: PhotoSpec?

    /// Decode `fileData`, measure the face, and export it to `spec`.
    ///
    /// `metricsOverride` substitutes measurements instead of running Vision — used only by the
    /// DEBUG launch hook, so the export/validation/result path can be driven where Vision is
    /// unavailable (the Simulator reports "E5RT is not supported").
    func load(_ fileData: Data, spec: PhotoSpec, backgroundHex: String?,
              metricsOverride: FaceMetrics? = nil,
              completion: @escaping @Sendable (Result<Outcome, ImportError>) -> Void) {
        queue.async { [self] in
            // Must go through ImageLoading: a portrait photo stores landscape pixels plus an
            // EXIF orientation tag, and measuring the raw pixels would export it sideways.
            guard let cg = ImageLoading.uprightCGImage(from: fileData, context: ciContext) else {
                completion(.failure(.decodeFailed)); return
            }
            let metrics: FaceMetrics
            if let metricsOverride {
                metrics = metricsOverride
            } else {
                do { metrics = try engine.metrics(from: cg) }
                catch { completion(.failure(.analysisFailed(String(describing: error)))); return }
            }
            guard metrics.faceCount != 0 else { completion(.failure(.noFace)); return }
            guard metrics.faceCount == 1 else { completion(.failure(.multipleFaces)); return }

            lastSource = cg; lastMetrics = metrics; lastSpec = spec
            guard let data = exportData(cg, metrics, spec, backgroundHex) else {
                completion(.failure(.exportFailed)); return
            }
            // Validate through the SAME crop the export just applied, so the verdict describes
            // the photo we produced rather than the untouched full frame.
            let framed = ExportGeometry.reprojected(metrics, spec: spec)
            let report = SpecValidator.validate(framed, against: spec)
            completion(.success(Outcome(data: data, report: report)))
        }
    }

    /// Re-export the imported photo in a different background color.
    func reexport(backgroundHex: String?, completion: @escaping @Sendable (Data?) -> Void) {
        queue.async { [self] in
            guard let cg = lastSource, let metrics = lastMetrics, let spec = lastSpec else {
                completion(nil); return
            }
            completion(exportData(cg, metrics, spec, backgroundHex))
        }
    }

    /// Render the print sheet for the imported photo. Nil when nothing has been imported.
    func printSheet(paper: ExportPipeline.PrintPaper, backgroundHex: String?,
                    completion: @escaping @Sendable (Data?) -> Void) {
        queue.async { [self] in
            guard let cg = lastSource, let metrics = lastMetrics, let spec = lastSpec else {
                completion(nil); return
            }
            completion(sheetData(cg, metrics, spec, backgroundHex, paper))
        }
    }

    private func exportData(_ cg: CGImage, _ metrics: FaceMetrics, _ spec: PhotoSpec,
                            _ backgroundHex: String?) -> Data? {
        let opts = ExportPipeline.Options(
            replaceBackground: spec.digitalEditPolicy == .allowed, backgroundHex: backgroundHex)
        guard let out = try? pipeline.export(image: cg, spec: spec, metrics: metrics, options: opts) else {
            return nil
        }
        return try? pipeline.jpegData(out, spec: spec)
    }

    private func sheetData(_ cg: CGImage, _ metrics: FaceMetrics, _ spec: PhotoSpec,
                           _ backgroundHex: String?, _ paper: ExportPipeline.PrintPaper) -> Data? {
        let opts = ExportPipeline.Options(
            replaceBackground: spec.digitalEditPolicy == .allowed, backgroundHex: backgroundHex)
        guard let photo = try? pipeline.export(image: cg, spec: spec, metrics: metrics, options: opts),
              let sheet = pipeline.printSheet(photo: photo, spec: spec, paper: paper) else { return nil }
        return try? pipeline.jpegData(sheet.image, dpi: spec.dpi)
    }
    #else
    func load(_ fileData: Data, spec: PhotoSpec, backgroundHex: String?,
              metricsOverride: FaceMetrics? = nil,
              completion: @escaping @Sendable (Result<Outcome, ImportError>) -> Void) {
        completion(.failure(.decodeFailed))
    }
    func reexport(backgroundHex: String?, completion: @escaping @Sendable (Data?) -> Void) { completion(nil) }
    func printSheet(paper: ExportPipeline.PrintPaper, backgroundHex: String?,
                    completion: @escaping @Sendable (Data?) -> Void) { completion(nil) }
    #endif
}
