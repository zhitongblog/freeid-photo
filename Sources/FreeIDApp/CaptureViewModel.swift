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

    /// Where the photo on the result screen came from. The two sources hold their own copy
    /// of the original frame, so re-exports (background color, print sheet) must be routed
    /// back to whichever one produced the current result.
    enum ResultSource { case camera, library }
    private(set) var resultSource: ResultSource = .camera

    /// For a photo picked from the library there is no live viewfinder to coach through the
    /// problems, so the verdict is reported once, after the fact, on the result screen.
    /// Nil for camera captures (they were coached live).
    var importReport: ComplianceReport?
    /// True while a picked photo is being decoded and exported.
    var isImporting = false

    let importer = PhotoImporter()

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

    /// Background colors offered for GENERAL portrait photos. The white/blue/red trio is the
    /// real-world standard for China 一寸/二寸 (résumés, certificates, social security, etc.).
    struct BackgroundChoice: Identifiable, Equatable {
        let name: String
        let hex: String
        var id: String { hex }
        static let white = BackgroundChoice(
            name: Loc8(zh: "白底", zhTW: "白底", en: "White", ja: "白", ko: "흰색", fr: "Blanc", de: "Weiß", it: "Bianco").t, hex: "#FFFFFF")
        static let blue = BackgroundChoice(
            name: Loc8(zh: "蓝底", zhTW: "藍底", en: "Blue", ja: "青", ko: "파랑", fr: "Bleu", de: "Blau", it: "Blu").t, hex: "#438EDB")
        static let red = BackgroundChoice(
            name: Loc8(zh: "红底", zhTW: "紅底", en: "Red", ja: "赤", ko: "빨강", fr: "Rouge", de: "Rot", it: "Rosso").t, hex: "#D9001B")
        static let all: [BackgroundChoice] = [.white, .blue, .red]
    }

    /// Color choice is offered ONLY for general portrait photos, which genuinely accept
    /// multiple backgrounds. Official documents (passports/visas/ID cards) mandate ONE
    /// specific background — even when digital editing is allowed we replace it to the
    /// spec's required color, never an arbitrary one — so the picker stays hidden there.
    var canChooseBackground: Bool {
        selectedSpec.digitalEditPolicy == .allowed && selectedSpec.docType == .general
    }

    /// True when the background was auto-replaced to the document's required color (an
    /// editable official doc) — shown as reassurance instead of a color picker.
    var backgroundLockedToSpec: Bool {
        selectedSpec.digitalEditPolicy == .allowed && selectedSpec.docType != .general
    }

    /// Pick a background color and instantly re-export the last shot in that color.
    func chooseBackground(_ hex: String) {
        backgroundHex = hex
        guard canChooseBackground, exportedData != nil else { return }
        let apply: @Sendable (Data?) -> Void = { data in
            Task { @MainActor [weak self] in if let data { self?.exportedData = data } }
        }
        switch resultSource {
        case .camera:  camera.reexport(backgroundHex: hex, completion: apply)
        case .library: importer.reexport(backgroundHex: hex, completion: apply)
        }
    }

    /// Build a print sheet — copies of the finished photo tiled onto `paper` — from whichever
    /// source produced the current result. Hands back JPEG bytes to save or share.
    func makePrintSheet(paper: ExportPipeline.PrintPaper,
                        completion: @escaping @Sendable (Data?) -> Void) {
        let hex = canChooseBackground ? backgroundHex : nil
        switch resultSource {
        case .camera:  camera.printSheet(paper: paper, backgroundHex: hex, completion: completion)
        case .library: importer.printSheet(paper: paper, backgroundHex: hex, completion: completion)
        }
    }

    /// How many copies `paper` fits for the selected spec — shown on the picker so the user
    /// can choose the paper that gives them the most prints.
    func copies(on paper: ExportPipeline.PrintPaper) -> Int {
        ExportPipeline().copiesPerSheet(spec: selectedSpec, paper: paper)
    }

    /// Run a photo from the user's library through the same pipeline as a live capture.
    /// This is the path for photos that can't be shot in the viewfinder — a baby who won't
    /// hold still, a shot someone else already took.
    func importPhoto(_ fileData: Data, metricsOverride: FaceMetrics? = nil) {
        guard !isImporting else { return }
        isImporting = true
        captureError = nil
        importer.load(fileData, spec: selectedSpec,
                      backgroundHex: canChooseBackground ? backgroundHex : nil,
                      metricsOverride: metricsOverride) { result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isImporting = false
                switch result {
                case .success(let outcome):
                    self.resultSource = .library
                    self.exportedData = outcome.data
                    // Only report what the user has to act on. Framing, background and exposure
                    // on edit-allowed specs are fixed by the export, so flagging them would be
                    // scolding the user for something we already handled.
                    self.importReport = outcome.report
                    self.showResult = true
                case .failure(let error):
                    #if DEBUG
                    Self.breadcrumb("import failed: \(error) (\(fileData.count) bytes)")
                    #endif
                    self.captureError = Self.message(for: error)
                }
            }
        }
    }

    #if DEBUG
    /// Test hook: `-import-photo <path> [-spec <id>]` runs the library-import flow on a file
    /// instead of a picked photo, so the whole path can be driven from a script or the
    /// Simulator (where `simctl addmedia` is unreliable). DEBUG only — never in a release build.
    func runImportLaunchHookIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-import-photo"), i + 1 < args.count else { return }
        if let j = args.firstIndex(of: "-spec"), j + 1 < args.count,
           let spec = library.spec(id: args[j + 1]) {
            selectedSpec = spec
        }
        let path = args[i + 1]
        guard let data = FileManager.default.contents(atPath: path) else {
            Self.breadcrumb("cannot read \(path)")
            captureError = S.importUnreadable.t
            return
        }
        // Optional pre-measured FaceMetrics (from `freeidctl measure`), for running where
        // Vision is unavailable.
        var override: FaceMetrics?
        if let m = args.firstIndex(of: "-metrics"), m + 1 < args.count,
           let raw = FileManager.default.contents(atPath: args[m + 1]) {
            override = try? JSONDecoder().decode(FaceMetrics.self, from: raw)
            Self.breadcrumb("metrics override: \(override == nil ? "FAILED TO DECODE" : "loaded")")
        }
        Self.breadcrumb("importing \(data.count) bytes as \(selectedSpec.id)")
        importPhoto(data, metricsOverride: override)
    }

    /// The Simulator swallows stdout, so harness diagnostics go to a file in the app's own
    /// container where the test script can read them back.
    static func breadcrumb(_ line: String) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("harness.log")
        let text = line + "\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile(); handle.write(Data(text.utf8)); try? handle.close()
        } else {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    #endif

    private static func message(for error: PhotoImporter.ImportError) -> String {
        switch error {
        case .noFace:        return S.importNoFace.t
        case .multipleFaces: return S.importManyFaces.t
        case .decodeFailed, .analysisFailed:  return S.importUnreadable.t
        case .exportFailed:  return S.captureError.t
        }
    }

    /// Problems the user has to fix themselves by picking or shooting a different photo.
    /// Everything the export corrects (crop, centering, and — on edit-allowed specs — the
    /// background) is deliberately left out.
    var importIssues: [Loc8] {
        guard let report = importReport else { return [] }
        let bgHandled = selectedSpec.digitalEditPolicy == .allowed
        var seen = Set<String>()
        return report.failures.compactMap { check -> Loc8? in
            if bgHandled && check.id.hasPrefix("background.") { return nil }
            // Several check ids collapse onto one piece of advice (both background checks,
            // all three framing checks). Say it once.
            guard let text = Self.issueText(check.id), seen.insert(text.en).inserted else { return nil }
            return text
        }
    }

    /// Map a validator check id onto app UI copy. The core's own `LocalizedText` carries only
    /// en/zh; the app ships in 8 languages, so the user-facing wording lives here.
    private static func issueText(_ id: String) -> Loc8? {
        switch id {
        case "pose":        return S.issuePose
        case "eyesOpen":    return S.issueEyes
        case "mouthClosed", "neutral": return S.issueExpression
        case "glasses":     return S.issueGlasses
        case "exposure":    return S.issueLighting
        case "background.uniformity", "background.color": return S.issueBackground
        case "headHeight", "eyeLine", "centering": return S.issueFraming
        default: return nil
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
                    self.resultSource = .camera
                    self.importReport = nil   // the viewfinder already coached this one live
                    self.exportedData = data
                    self.showResult = true
                } else {
                    self.captureError = S.captureError.t
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
