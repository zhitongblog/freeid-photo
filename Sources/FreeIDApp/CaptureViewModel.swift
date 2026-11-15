import Foundation
import SwiftUI
import FreeIDCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

/// App-wide state for the capture flow: which spec is selected, the latest live
/// compliance report from the camera, local history originals, and the captured/exported result.
@MainActor
@Observable
final class CaptureViewModel {
    let library: SpecLibrary
    var selectedSpec: PhotoSpec {
        didSet {
            camera.spec = selectedSpec
            // Sync default background swatch when switching to a general spec whose default
            // is e.g. blue (cn-grad 480x640), and automatically re-export if ResultScreen is open!
            if selectedSpec.docType == .general {
                backgroundHex = selectedSpec.background.hex
            }
            if selectedSpec.digitalEditPolicy == .strict {
                brightnessBoost = 0
                skinSmoothing = 0
            }
            if showResult && exportedData != nil {
                reexportCurrent()
            }
        }
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

    enum ResultSource { case camera, library }
    private(set) var resultSource: ResultSource = .camera

    /// Post-hoc compliance report on imported/history photos (or when switching spec on ResultScreen).
    var importReport: ComplianceReport?
    /// True while a picked photo is being decoded and exported.
    var isImporting = false

    let importer = PhotoImporter()
    let historyStore = PhotoHistoryStore()
    var historyEntries: [PhotoHistoryStore.Entry] = []

    /// Chosen background color (#RRGGBB). Applied on edit-allowed general specs.
    var backgroundHex: String = BackgroundChoice.white.hex
    /// Gentle brightness lift (-0.20 ... +0.20) on edit-allowed specs.
    var brightnessBoost: Double = 0.0
    /// Natural skin smoothing (0.0 ... 1.0) on edit-allowed specs.
    var skinSmoothing: Double = 0.0

    /// True when the back camera is active.
    var usingBackCamera = false

    let camera = CameraController()
    #if canImport(AVFoundation)
    private let speechSynthesizer = AVSpeechSynthesizer()
    #endif
    private var lastSpokenHint: CaptureHint?
    private var lastSpokenAt: Date = .distantPast
    private var readySince: Date?
    private var reexportGeneration: Int = 0

    init() {
        let lib = (try? SpecLibrary.bundled()) ?? SpecLibrary(specs: [])
        self.library = lib
        self.selectedSpec = lib.spec(id: "cn-1inch") ?? lib.specs.first ?? CaptureViewModel.placeholderSpec
        self.historyEntries = historyStore.loadEntries()
        camera.spec = selectedSpec
        camera.onReport = { [weak self] report in
            self?.handleLiveReport(report)
        }
    }

    private func handleLiveReport(_ report: ComplianceReport) {
        liveReport = report
        guard usingBackCamera, !showResult, !isCapturing, !isImporting else {
            readySince = nil
            return
        }
        let hint = liveHint
        let now = Date()
        if hint == .ready {
            if readySince == nil {
                readySince = now
                speakIfNeeded(hint: .ready, now: now)
            } else if let since = readySince, now.timeIntervalSince(since) >= 1.2 {
                readySince = nil
                capture()
            }
        } else {
            readySince = nil
            speakIfNeeded(hint: hint, now: now)
        }
    }

    private func speakIfNeeded(hint: CaptureHint, now: Date) {
        #if canImport(AVFoundation)
        let interval = (hint == lastSpokenHint) ? 4.0 : 2.2
        guard now.timeIntervalSince(lastSpokenAt) >= interval, !speechSynthesizer.isSpeaking else { return }
        let phrase: String
        switch hint {
        case .ready:      phrase = S.coachReady.t
        case .findFace:   phrase = S.coachFindFace.t
        case .onePerson:  phrase = S.coachOnePerson.t
        case .straighten: phrase = S.coachStraighten.t
        case .moveCloser: phrase = S.coachCloser.t
        case .moveBack:   phrase = S.coachBack.t
        }
        let utterance = AVSpeechUtterance(string: phrase)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)
        lastSpokenHint = hint
        lastSpokenAt = now
        #endif
    }

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

    var canChooseBackground: Bool {
        selectedSpec.digitalEditPolicy == .allowed && selectedSpec.docType == .general
    }

    /// Portrait brightness & natural skin smoothing are available on any edit-allowed spec,
    /// and strictly hidden on `.strict` specs (US, UK, Canada, etc.).
    var canRetouchPortrait: Bool {
        selectedSpec.digitalEditPolicy == .allowed
    }

    var hasActiveAdjustments: Bool {
        abs(brightnessBoost) > 0.005 || skinSmoothing > 0.005
    }

    var backgroundLockedToSpec: Bool {
        selectedSpec.digitalEditPolicy == .allowed && selectedSpec.docType != .general
    }

    /// Pick a background color and instantly re-export the current shot.
    func chooseBackground(_ hex: String) {
        backgroundHex = hex
        guard canChooseBackground, exportedData != nil else { return }
        reexportCurrent()
    }

    /// Reset brightness & smoothing sliders and re-export cleanly.
    func resetAdjustments() {
        brightnessBoost = 0
        skinSmoothing = 0
        reexportCurrent()
    }

    /// Re-export the active shot (camera or library/history) with current `selectedSpec`,
    /// `backgroundHex`, `brightnessBoost`, and `skinSmoothing`. Generation-stamped so rapid
    /// slider drags never apply stale frames out of order.
    func reexportCurrent() {
        guard exportedData != nil else { return }
        reexportGeneration += 1
        let gen = reexportGeneration
        let spec = selectedSpec
        let hex = canChooseBackground ? backgroundHex : nil
        let bri = canRetouchPortrait ? brightnessBoost : 0
        let smooth = canRetouchPortrait ? skinSmoothing : 0

        switch resultSource {
        case .camera:
            camera.reexport(spec: spec, backgroundHex: hex, brightnessBoost: bri, skinSmoothing: smooth) { [weak self] data in
                Task { @MainActor in
                    guard let self, self.reexportGeneration == gen, let data else { return }
                    self.exportedData = data
                }
            }
        case .library:
            importer.reexport(spec: spec, backgroundHex: hex, brightnessBoost: bri, skinSmoothing: smooth) { [weak self] res in
                Task { @MainActor in
                    guard let self, self.reexportGeneration == gen, let res else { return }
                    self.exportedData = res.data
                    self.importReport = res.report
                }
            }
        }
    }

    /// Build a print sheet from whichever source produced the current result.
    func makePrintSheet(paper: ExportPipeline.PrintPaper,
                        completion: @escaping @Sendable (Data?) -> Void) {
        let spec = selectedSpec
        let hex = canChooseBackground ? backgroundHex : nil
        let bri = canRetouchPortrait ? brightnessBoost : 0
        let smooth = canRetouchPortrait ? skinSmoothing : 0
        switch resultSource {
        case .camera:
            camera.printSheet(spec: spec, paper: paper, backgroundHex: hex,
                              brightnessBoost: bri, skinSmoothing: smooth, completion: completion)
        case .library:
            importer.printSheet(spec: spec, paper: paper, backgroundHex: hex,
                                brightnessBoost: bri, skinSmoothing: smooth, completion: completion)
        }
    }

    func copies(on paper: ExportPipeline.PrintPaper) -> Int {
        ExportPipeline().copiesPerSheet(spec: selectedSpec, paper: paper)
    }

    /// Import a photo from the user's library (or from local History when `saveToHistory == false`).
    func importPhoto(_ fileData: Data, metricsOverride: FaceMetrics? = nil, saveToHistory: Bool = true) {
        guard !isImporting else { return }
        isImporting = true
        captureError = nil
        brightnessBoost = 0
        skinSmoothing = 0
        let spec = selectedSpec
        let hex = canChooseBackground ? backgroundHex : nil
        importer.load(fileData, spec: spec, backgroundHex: hex,
                      metricsOverride: metricsOverride) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isImporting = false
                switch result {
                case .success(let outcome):
                    self.resultSource = .library
                    self.exportedData = outcome.data
                    self.importReport = outcome.report
                    if saveToHistory {
                        self.recordHistory(jpegData: outcome.sourceJPEG, metrics: outcome.metrics, specID: spec.id)
                    }
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

    /// Open a saved local original from `PhotoHistoryStore` and export it in `selectedSpec`.
    func loadHistoryEntry(_ entry: PhotoHistoryStore.Entry) {
        guard let data = historyStore.imageData(for: entry.id) else {
            deleteHistoryEntry(entry.id)
            return
        }
        importPhoto(data, metricsOverride: entry.metrics, saveToHistory: false)
    }

    func deleteHistoryEntry(_ id: UUID) {
        historyStore.delete(id: id)
        historyEntries = historyStore.loadEntries()
    }

    func clearHistory() {
        historyStore.clearAll()
        historyEntries = []
    }

    private func recordHistory(jpegData: Data, metrics: FaceMetrics, specID: String) {
        _ = historyStore.saveOriginal(jpegData: jpegData, metrics: metrics, specID: specID)
        historyEntries = historyStore.loadEntries()
    }

    #if DEBUG
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
        var override: FaceMetrics?
        if let m = args.firstIndex(of: "-metrics"), m + 1 < args.count,
           let raw = FileManager.default.contents(atPath: args[m + 1]) {
            override = try? JSONDecoder().decode(FaceMetrics.self, from: raw)
            Self.breadcrumb("metrics override: \(override == nil ? "FAILED TO DECODE" : "loaded")")
        }
        Self.breadcrumb("importing \(data.count) bytes as \(selectedSpec.id)")
        importPhoto(data, metricsOverride: override)
    }

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

    /// Problems the user has to fix themselves (or self-check via advisory warnings like
    /// glasses/expression) on an imported photo.
    var importIssues: [Loc8] {
        guard let report = importReport else { return [] }
        let bgHandled = selectedSpec.digitalEditPolicy == .allowed
        var seen = Set<String>()
        let relevant = report.checks.filter { c in
            if c.status == .fail { return true }
            if c.status == .warn && (c.id == "glasses" || c.id == "neutral" || c.id == "mouthClosed" || c.id == "eyesOpen") {
                return true
            }
            return false
        }
        return relevant.compactMap { check -> Loc8? in
            if bgHandled && check.id.hasPrefix("background.") { return nil }
            guard let text = Self.issueText(check.id), seen.insert(text.en).inserted else { return nil }
            return text
        }
    }

    private static func issueText(_ id: String) -> Loc8? {
        switch id {
        case "pose":        return S.issuePose
        case "eyesOpen":    return S.issueEyes
        case "mouthClosed", "neutral": return S.issueExpression
        case "glasses":     return S.issueGlasses
        case "exposure":    return S.issueLighting
        case "faceLighting":return S.issueFaceLighting
        case "background.uniformity", "background.color": return S.issueBackground
        case "headHeight", "eyeLine", "centering": return S.issueFraming
        default: return nil
        }
    }

    func flipCamera() {
        camera.switchCamera()
        usingBackCamera.toggle()
        readySince = nil
        lastSpokenHint = nil
        #if canImport(AVFoundation)
        if !usingBackCamera && speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        #endif
    }

    var isLiveCompliant: Bool { liveReport?.isCompliant ?? false }

    var hasFace: Bool {
        liveReport?.checks.first { $0.id == "faceCount" }?.status == .pass
    }

    var liveHint: CaptureHint {
        guard let report = liveReport else { return .findFace }
        if !hasFace {
            let many = report.checks.contains { $0.id == "faceCount" && $0.detail.en.contains("More") }
            return many ? .onePerson : .findFace
        }
        func bad(_ id: String) -> Bool {
            report.checks.first { $0.id == id }?.status != .pass
        }
        if bad("pose") { return .straighten }
        if bad("headHeight") || bad("eyeLine") {
            let small = report.checks.first { $0.id == "headHeight" }?.detail.en.contains("small") ?? true
            return small ? .moveCloser : .moveBack
        }
        return .ready
    }

    enum CaptureHint: Equatable { case findFace, onePerson, straighten, moveCloser, moveBack, ready }

    func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        captureError = nil
        brightnessBoost = 0
        skinSmoothing = 0
        let spec = selectedSpec
        camera.captureAndExport(backgroundHex: canChooseBackground ? backgroundHex : nil) { [weak self] outcome in
            Task { @MainActor in
                guard let self else { return }
                self.isCapturing = false
                if let outcome {
                    self.resultSource = .camera
                    self.importReport = nil
                    self.exportedData = outcome.exportedData
                    self.recordHistory(jpegData: outcome.sourceJPEG, metrics: outcome.metrics, specID: spec.id)
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
