import Foundation
import SwiftUI
import FreeIDCore
#if canImport(UIKit)
import UIKit
#endif

/// App-wide state for the capture flow: which spec is selected, the latest live
/// compliance report from the camera, and the captured/exported result.
@MainActor
@Observable
final class CaptureViewModel {
    let library: SpecLibrary
    var selectedSpec: PhotoSpec {
        didSet { camera.spec = selectedSpec }
    }

    /// Latest live compliance report from the camera (nil until the first frame).
    var liveReport: ComplianceReport?
    /// Final spec-sized export, as JPEG data (Sendable across the capture boundary).
    var exportedData: Data?
    /// True while a capture is being processed.
    var isCapturing = false
    /// Drives presentation of the result screen.
    var showResult = false
    /// Set when a capture failed (e.g. no single face found at the moment of capture).
    var captureError: String?

    /// Chosen background color (#RRGGBB). Applied on edit-allowed specs; ignored on strict
    /// ones (which forbid background replacement). Defaults to white.
    var backgroundHex: String = BackgroundChoice.white.hex
    /// True when the back camera is active (someone else is taking the photo for you).
    var usingBackCamera = false

    let camera = CameraController()

    init() {
        let lib = (try? SpecLibrary.bundled()) ?? SpecLibrary(specs: [])
        self.library = lib
        // Default to a common home-market spec if present, else the first one.
        self.selectedSpec = lib.spec(id: "cn-1inch") ?? lib.specs.first ?? CaptureViewModel.placeholderSpec
        camera.spec = selectedSpec
        camera.onReport = { [weak self] report in
            self?.liveReport = report
        }
    }

    /// Standard ID-photo background colors offered to the user.
    struct BackgroundChoice: Identifiable, Equatable {
        let name: LocalizedText
        let hex: String
        var id: String { hex }
        static let white = BackgroundChoice(name: .init(en: "White", zh: "白底"), hex: "#FFFFFF")
        static let blue  = BackgroundChoice(name: .init(en: "Blue",  zh: "蓝底"), hex: "#438EDB")
        static let red   = BackgroundChoice(name: .init(en: "Red",   zh: "红底"), hex: "#D9001B")
        static let gray  = BackgroundChoice(name: .init(en: "Gray",  zh: "灰底"), hex: "#D8D8D8")
        static let all: [BackgroundChoice] = [.white, .blue, .red, .gray]
    }

    /// Background swatches only make sense where digital replacement is allowed (e.g. China);
    /// strict specs (US/UK passports) must use a real backdrop, so we hide the picker.
    var canChooseBackground: Bool { selectedSpec.digitalEditPolicy == .allowed }

    /// Pick a background color and instantly re-export the last shot in that color.
    func chooseBackground(_ hex: String) {
        backgroundHex = hex
        guard canChooseBackground, exportedData != nil else { return }
        camera.reexport(backgroundHex: hex) { data in
            Task { @MainActor [weak self] in if let data { self?.exportedData = data } }
        }
    }

    /// Flip between the selfie camera and the back camera (for a helper to shoot you).
    func flipCamera() {
        camera.switchCamera()
        usingBackCamera.toggle()
    }

    var isLiveCompliant: Bool { liveReport?.isCompliant ?? false }

    /// True once a single face is in frame. The shutter unlocks on THIS, not on full
    /// compliance: capturing is always allowed when there's a face to work with, and the
    /// export pipeline auto-corrects framing/background/exposure. Compliance is shown as
    /// gentle live guidance, never a gate — this is a consumer app, not a pro checklist.
    var hasFace: Bool {
        liveReport?.checks.first { $0.id == "faceCount" }?.status == .pass
    }

    /// One friendly coaching line — the single most useful thing to adjust right now, or
    /// `.ready` when we're good to shoot. Replaces the wall of red X's: we only nudge on
    /// things the user must physically do (find the frame, move back/closer, sit straight).
    /// Crop, centering drift, background and exposure are auto-fixed on export, so we stay
    /// quiet about them.
    var liveHint: CaptureHint {
        guard let report = liveReport else { return .findFace }
        if !hasFace {
            let many = report.checks.contains { $0.id == "faceCount" && $0.detail.en.contains("More") }
            return many ? .onePerson : .findFace
        }
        // Coach on geometry/pose whether it reads as fail (strict) or warn (auto-fix specs),
        // because "move back a little" is genuinely useful guidance either way.
        func bad(_ id: String) -> Bool {
            report.checks.first { $0.id == id }?.status != .pass
        }
        if bad("pose") { return .straighten }
        if bad("headHeight") || bad("eyeLine") {
            // Head too small → move closer; too big → move back. Read the headHeight detail.
            let small = report.checks.first { $0.id == "headHeight" }?.detail.en.contains("small") ?? true
            return small ? .moveCloser : .moveBack
        }
        return .ready
    }

    enum CaptureHint: Equatable { case findFace, onePerson, straighten, moveCloser, moveBack, ready }

    /// Capture a still and run it through the export pipeline. On success, `exportedData`
    /// holds the spec-sized photo and `showResult` flips true.
    func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        captureError = nil
        camera.captureAndExport(backgroundHex: canChooseBackground ? backgroundHex : nil) { data in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isCapturing = false
                if let data {
                    self.exportedData = data
                    self.showResult = true
                } else {
                    self.captureError = localeCode.hasPrefix("zh")
                        ? "没拍清楚，让脸保持在框里再试一次就好"
                        : "Didn't catch that — keep your face in the frame and tap again."
                }
            }
        }
    }

    func specsGroupedByCountry() -> [(country: String, specs: [PhotoSpec])] {
        library.countries.map { ($0, library.specs(country: $0)) }
    }

    /// Fallback spec so the UI never has a nil selection (used only if the bundle is empty).
    static let placeholderSpec = PhotoSpec(
        id: "none", country: "??", docType: .general,
        displayName: LocalizedText(en: "No specs", zh: "无规格"),
        outputSize: PhysicalSize(widthMM: 35, heightMM: 45), dpi: 300,
        headHeight: RangeMM(min: 30, max: 36), eyeLineFromBottom: RangeMM(min: 28, max: 34),
        background: BackgroundRule(name: "White", hex: "#FFFFFF", toleranceDeltaE: 12, minUniformity: 0.85),
        digitalEditPolicy: .allowed,
        expression: ExpressionRule(neutral: true, mouthClosed: true, eyesOpen: true),
        glasses: .forbidden, fileSpec: nil, officialSourceURL: "", lastVerified: "")
}
