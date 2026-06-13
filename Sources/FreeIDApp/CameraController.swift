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
/// Capture work stays on the camera queue; only Sendable `Data` crosses back to the UI,
/// so it's clean under Swift 6 concurrency. On the Simulator there is no camera, so the
/// app still builds and renders; capture/preview are verified on a real device.
final class CameraController: NSObject {

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

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted, let self else { return }
            self.queue.async { self.configureIfNeeded(); self.session.startRunning() }
        }
    }

    func stop() { queue.async { [weak self] in self?.session.stopRunning() } }

    /// Capture a still and run it through the export pipeline for `spec`. For edit-allowed
    /// specs the background is replaced to meet the spec color; strict specs keep the real
    /// photo (crop/resize only). Returns spec-sized JPEG data, or nil on failure.
    func captureAndExport(completion: @escaping @Sendable (Data?) -> Void) {
        queue.async {
            guard self.spec != nil else { completion(nil); return }
            self.captureCompletion = completion
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()
    }
    #else
    func start() {}
    func stop() {}
    func captureAndExport(completion: @escaping @Sendable (Data?) -> Void) { completion(nil) }
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
        let report = SpecValidator.validate(metrics, against: spec)
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
              let src = CGImageSourceCreateWithData(fileData as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil),
              let spec else { finish(nil); return }

        guard let metrics = try? engine.metrics(from: cg), metrics.faceCount == 1 else { finish(nil); return }
        let opts = ExportPipeline.Options(replaceBackground: spec.digitalEditPolicy == .allowed)
        guard let out = try? pipeline.export(image: cg, spec: spec, metrics: metrics, options: opts),
              let data = try? pipeline.jpegData(out) else { finish(nil); return }
        finish(data)
    }
}
#endif
