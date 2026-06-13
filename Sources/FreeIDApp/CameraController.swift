import Foundation
import FreeIDCore
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(CoreImage)
import CoreImage
#endif

/// Drives the front camera and runs the compliance engine on a throttled stream of
/// frames, publishing a live ComplianceReport for the chosen spec.
///
///   AVCaptureSession ─frames─▶ (serial queue, every Nth) ─▶ VisionComplianceEngine
///        ─▶ SpecValidator ─▶ onReport(report) on the main actor
///
/// On the Simulator there is no camera, so no frames arrive; the app still builds and
/// the UI renders. Live accuracy is verified on a real device (see /ios-qa).
final class CameraController: NSObject {

    /// The spec the live stream is validated against. Set from the view model.
    var spec: PhotoSpec?
    /// Called on the main actor with each new live report.
    var onReport: (@MainActor (ComplianceReport) -> Void)?

    #if canImport(AVFoundation) && os(iOS)
    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "freeid.camera.frames")
    private let engine = VisionComplianceEngine()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var frameCounter = 0
    private let processEveryNthFrame = 4
    private var configured = false

    /// Request permission and start the session.
    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted, let self else { return }
            self.queue.async { self.configureIfNeeded(); self.session.startRunning() }
        }
    }

    func stop() {
        queue.async { [weak self] in self?.session.stopRunning() }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
    }
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
        guard let cg = ciContext.createCGImage(ci, from: ci.extent) else { return }
        guard let metrics = try? engine.metrics(from: cg) else { return }
        let report = SpecValidator.validate(metrics, against: spec)
        let cb = onReport
        Task { @MainActor in cb?(report) }
    }
}
#endif
