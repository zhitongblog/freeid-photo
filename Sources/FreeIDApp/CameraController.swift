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

/// Drives the front camera: a throttled live stream for the compliance HUD, plus a
/// full-resolution still capture that runs straight through the export pipeline.
///
///   live:    AVCaptureVideoDataOutput ─(every Nth frame)→ engine → SpecValidator → onReport
///   capture: AVCapturePhotoOutput ─→ engine.metrics → ExportPipeline.export → JPEG Data
///
///Capture work stays on the camera queue; only Sendable `Data` crosses back to the UI,
/// so it's clean under Swift 6 concurrency. On the Simulator there is no camera, so the
/// app still builds and renders; capture/preview are verified on a real device.
final class CameraController: NSObject, @unchecked Sendable {

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
    private var captureCompletion: (@Sendable (Data?) -> Void)?
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
    /// different background color without making the user shoot again.
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

    /// Capture a still and run it through the export pipeline for `spec`. For edit-allowed
    /// specs the background is replaced (to `backgroundHex`, or the spec's default if nil);
    /// strict specs keep the real photo (crop/resize only). Returns spec-sized JPEG, or nil.
    func captureAndExport(backgroundHex: String?, completion: @escaping @Sendable (Data?) -> Void) {
        queue.async {
            guard self.spec != nil else { completion(nil); return }
            self.pendingBackgroundHex = backgroundHex
            // Orient the still to the CURRENT physical orientation at the moment of capture,
            // so a portrait shot is delivered (and tagged) upright rather than sideways.
            self.applyRotation(to: self.photoOutput.connection(with: .video))
            self.captureCompletion = completion
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    /// Re-run the export on the LAST captured frame with a new background color — lets the
    /// result screen preview white/blue/red/gray instantly without re-shooting.
    func reexport(backgroundHex: String?, completion: @escaping @Sendable (Data?) -> Void) {
        queue.async {
            guard let cg = self.lastSource, let metrics = self.lastMetrics, let spec = self.spec else {
                completion(nil); return
            }
            completion(self.exportData(from: cg, metrics: metrics, spec: spec, backgroundHex: backgroundHex))
        }
    }

    /// Render a print sheet from the LAST captured frame — copies of the finished photo laid
    /// out on photo-lab paper, so the user can hand one file to a print counter.
    func printSheet(paper: ExportPipeline.PrintPaper, backgroundHex: String?,
                    completion: @escaping @Sendable (Data?) -> Void) {
        queue.async {
            guard let cg = self.lastSource, let metrics = self.lastMetrics, let spec = self.spec else {
                completion(nil); return
            }
            let opts = ExportPipeline.Options(
                replaceBackground: spec.digitalEditPolicy == .allowed, backgroundHex: backgroundHex)
            guard let photo = try? self.pipeline.export(image: cg, spec: spec, metrics: metrics, options: opts),
                  let sheet = self.pipeline.printSheet(photo: photo, spec: spec, paper: paper) else {
                completion(nil); return
            }
            completion(try? self.pipeline.jpegData(sheet.image, dpi: spec.dpi))
        }
    }

    /// Flip between the front (selfie) and back (someone-helps) camera, reconfiguring the
    /// session input and rebuilding the rotation coordinator for the new device.
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

    /// Rebuild `AVCaptureDevice.RotationCoordinator` bound to the active device and preview
    /// layer, and observe both preview and capture rotation angles so unfolding/rotating an
    /// iPhone Duo (or switching displays/postures) keeps the preview and video feed upright.
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

    /// Shared crop + optional background replace + encode, used by both capture and re-export.
    private func exportData(from cg: CGImage, metrics: FaceMetrics, spec: PhotoSpec,
                            backgroundHex: String?) -> Data? {
        let opts = ExportPipeline.Options(
            replaceBackground: spec.digitalEditPolicy == .allowed, backgroundHex: backgroundHex)
        guard let out = try? pipeline.export(image: cg, spec: spec, metrics: metrics, options: opts) else {
            return nil
        }
        return try? pipeline.jpegData(out, spec: spec)
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

    /// Set a connection's rotation to keep video/photo upright for the current orientation.
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
    func captureAndExport(backgroundHex: String?, completion: @escaping @Sendable (Data?) -> Void) { completion(nil) }
    func reexport(backgroundHex: String?, completion: @escaping @Sendable (Data?) -> Void) { completion(nil) }
    func printSheet(paper: ExportPipeline.PrintPaper, backgroundHex: String?,
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
        // The live frame is the full sensor image, not pre-framed to the spec. Reproject
        // through the export crop so head/eye/centering reflect the photo we'd actually
        // produce — otherwise those checks fail on the whole frame and lock the shutter.
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
        func finish(_ data: Data?) { DispatchQueue.main.async { completion?(data) } }

        guard error == nil, let fileData = photo.fileDataRepresentation(),
              let cg = ImageLoading.uprightCGImage(from: fileData, context: ciContext),
              let spec else { finish(nil); return }

        guard let metrics = try? engine.metrics(from: cg), metrics.faceCount == 1 else { finish(nil); return }
        // Keep the source so the result screen can re-export with a different background color.
        lastSource = cg
        lastMetrics = metrics
        finish(exportData(from: cg, metrics: metrics, spec: spec, backgroundHex: pendingBackgroundHex))
    }
}
#endif
