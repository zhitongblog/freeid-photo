import Foundation
import FreeIDCore
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(CoreImage)
import CoreImage
#endif
#if canImport(ImageIO)
import ImageIO
#endif

/// Drives the front/back camera: a throttled live stream for the compliance HUD, plus a
/// full-resolution still capture that runs straight through the export pipeline.
///
///   live:    AVCaptureVideoDataOutput ─(every Nth frame)→ engine → SpecValidator → onReport
///   capture: AVCapturePhotoOutput ─→ engine.metrics → ExportPipeline.export → JPEG Data
///
/// Capture work stays on the camera queue; only Sendable `Data` / `FaceMetrics` cross back to
/// the UI, so it's clean under Swift 6 concurrency. On the Simulator there is no camera, so
/// the app still builds and renders; capture/preview are verified on a real device.
final class CameraController: NSObject, @unchecked Sendable {

    struct CaptureOutcome: Sendable {
        let exportedData: Data
        let sourceJPEG: Data
        let metrics: FaceMetrics
    }

    var spec: PhotoSpec?
    var onReport: (@MainActor (ComplianceReport) -> Void)?

    #if canImport(AVFoundation) && os(iOS)
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "freeid.camera")
    private let engine = VisionComplianceEngine()
    private let pipeline = ExportPipeline()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var frameCounter = 0
    private let processEveryNthFrame = 4
    private var configured = false
    private var captureCompletion: (@Sendable (CaptureOutcome?) -> Void)?
    private var captureDevice: AVCaptureDevice?
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    /// Tracks the physical orientation so we can deliver upright frames/photos and keep the
    /// live preview horizon-level across rotations and foldable (iPhone Duo) display transitions.
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?
    private var captureRotationObservation: NSKeyValueObservation?
    /// Front for selfies, back when someone else takes the photo for you (sharper lens).
    private(set) var cameraPosition: AVCaptureDevice.Position = .front
    /// Background color (#RRGGBB) to composite behind the subject; nil = the spec's default.
    private var pendingBackgroundHex: String?
    /// The last captured frame + its metrics, kept so the result screen can re-export with a
    /// different spec, background color, or brightness/smoothing without shooting again.
    private var lastSource: CGImage?
    private var lastMetrics: FaceMetrics?

    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        queue.async {
            self.rebuildRotationCoordinator()
        }
    }

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted, let self else { return }
            self.queue.async {
                self.configureIfNeeded()
                self.session.startRunning()
                self.rebuildRotationCoordinator()
            }
        }
    }

    func stop() { queue.async { [weak self] in self?.session.stopRunning() } }

    /// Capture a still and run it through the export pipeline for `spec`. Returns the finished
    /// JPEG plus a downscaled upright original JPEG + metrics for local history storage.
    func captureAndExport(backgroundHex: String?, completion: @escaping @Sendable (CaptureOutcome?) -> Void) {
        queue.async {
            guard self.spec != nil else { completion(nil); return }
            self.pendingBackgroundHex = backgroundHex
            self.applyRotation(to: self.photoOutput.connection(with: .video))
            self.captureCompletion = completion
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    /// Re-run the export on the LAST captured frame for `targetSpec` with updated background
    /// color or brightness/skin adjustments.
    func reexport(
        spec targetSpec: PhotoSpec,
        backgroundHex: String?,
        brightnessBoost: Double = 0,
        skinSmoothing: Double = 0,
        completion: @escaping @Sendable (Data?) -> Void
    ) {
        queue.async {
            guard let cg = self.lastSource, let metrics = self.lastMetrics else {
                completion(nil); return
            }
            completion(self.exportData(
                from: cg, metrics: metrics, spec: targetSpec,
                backgroundHex: backgroundHex,
                brightnessBoost: brightnessBoost, skinSmoothing: skinSmoothing))
        }
    }

    /// Render a print sheet from the LAST captured frame.
    func printSheet(
        spec targetSpec: PhotoSpec,
        paper: ExportPipeline.PrintPaper,
        backgroundHex: String?,
        brightnessBoost: Double = 0,
        skinSmoothing: Double = 0,
        completion: @escaping @Sendable (Data?) -> Void
    ) {
        queue.async {
            guard let cg = self.lastSource, let metrics = self.lastMetrics else {
                completion(nil); return
            }
            let opts = ExportPipeline.Options(
                replaceBackground: targetSpec.digitalEditPolicy == .allowed,
                backgroundHex: backgroundHex,
                brightnessBoost: brightnessBoost,
                skinSmoothing: skinSmoothing)
            guard let photo = try? self.pipeline.export(image: cg, spec: targetSpec, metrics: metrics, options: opts),
                  let sheet = self.pipeline.printSheet(photo: photo, spec: targetSpec, paper: paper) else {
                completion(nil); return
            }
            completion(try? self.pipeline.jpegData(sheet.image, dpi: targetSpec.dpi))
        }
    }

    /// Flip between the front (selfie) and back (someone-helps) camera.
    func switchCamera() {
        queue.async {
            self.session.beginConfiguration()
            for input in self.session.inputs { self.session.removeInput(input) }
            self.cameraPosition = (self.cameraPosition == .front) ? .back : .front
            self.addCameraInput(position: self.cameraPosition)
            self.session.commitConfiguration()
            self.rebuildRotationCoordinator()
        }
    }

    private func addCameraInput(position: AVCaptureDevice.Position) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
        session.addInput(input)
        captureDevice = device
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true
        session.beginConfiguration()
        session.sessionPreset = .photo
        addCameraInput(position: cameraPosition)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()
        rebuildRotationCoordinator()
    }

    private func rebuildRotationCoordinator() {
        guard let device = captureDevice else { return }
        let coord = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coord

        applyPreviewRotation(coord.videoRotationAngleForHorizonLevelPreview)
        applyCaptureRotation(coord.videoRotationAngleForHorizonLevelCapture)

        previewRotationObservation = coord.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] coord, _ in
            let angle = coord.videoRotationAngleForHorizonLevelPreview
            self?.applyPreviewRotation(angle)
        }
        captureRotationObservation = coord.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] coord, _ in
            guard let self else { return }
            let angle = coord.videoRotationAngleForHorizonLevelCapture
            self.queue.async { self.applyCaptureRotation(angle) }
        }
    }

    private func exportData(
        from cg: CGImage, metrics: FaceMetrics, spec: PhotoSpec,
        backgroundHex: String?, brightnessBoost: Double = 0, skinSmoothing: Double = 0
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

    /// Downscale high-megapixel originals to ≤ 2000px on the long edge before saving to local
    /// history so each entry takes ~250 KB instead of 6 MB while preserving plenty of detail.
    fileprivate func historyJPEG(from cg: CGImage) -> Data? {
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

    private func applyPreviewRotation(_ angle: CGFloat) {
        DispatchQueue.main.async { [weak self] in
            guard let conn = self?.previewLayer?.connection, conn.isVideoRotationAngleSupported(angle) else { return }
            conn.videoRotationAngle = angle
        }
    }

    private func applyCaptureRotation(_ angle: CGFloat) {
        if let conn = videoOutput.connection(with: .video), conn.isVideoRotationAngleSupported(angle) {
            conn.videoRotationAngle = angle
        }
    }

    private func applyRotation(to connection: AVCaptureConnection?) {
        guard let connection, let coord = rotationCoordinator else { return }
        let angle = coord.videoRotationAngleForHorizonLevelCapture
        if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
    }
    #else
    var cameraPosition: Int { 0 }
    func start() {}
    func stop() {}
    func switchCamera() {}
    func captureAndExport(backgroundHex: String?, completion: @escaping @Sendable (CaptureOutcome?) -> Void) { completion(nil) }
    func reexport(spec targetSpec: PhotoSpec, backgroundHex: String?, brightnessBoost: Double = 0,
                  skinSmoothing: Double = 0, completion: @escaping @Sendable (Data?) -> Void) { completion(nil) }
    func printSheet(spec targetSpec: PhotoSpec, paper: ExportPipeline.PrintPaper, backgroundHex: String?,
                    brightnessBoost: Double = 0, skinSmoothing: Double = 0,
                    completion: @escaping @Sendable (Data?) -> Void) { completion(nil) }
    #endif
}

#if canImport(AVFoundation) && os(iOS)
extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameCounter += 1
        guard frameCounter % processEveryNthFrame == 0,
              let spec, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cg = ciContext.createCGImage(ci, from: ci.extent),
              let metrics = try? engine.metrics(from: cg) else { return }
        let framed = ExportGeometry.reprojected(metrics, spec: spec)
        let report = SpecValidator.validate(framed, against: spec)
        let cb = onReport
        Task { @MainActor in cb?(report) }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let completion = captureCompletion
        captureCompletion = nil
        func finish(_ outcome: CaptureOutcome?) { DispatchQueue.main.async { completion?(outcome) } }

        guard error == nil, let fileData = photo.fileDataRepresentation(),
              let cg = ImageLoading.uprightCGImage(from: fileData, context: ciContext),
              let spec else { finish(nil); return }

        guard let metrics = try? engine.metrics(from: cg), metrics.faceCount == 1 else { finish(nil); return }
        lastSource = cg
        lastMetrics = metrics
        guard let exported = exportData(from: cg, metrics: metrics, spec: spec, backgroundHex: pendingBackgroundHex) else {
            finish(nil); return
        }
        let srcJPEG = historyJPEG(from: cg) ?? exported
        finish(CaptureOutcome(exportedData: exported, sourceJPEG: srcJPEG, metrics: metrics))
    }
}
#endif
