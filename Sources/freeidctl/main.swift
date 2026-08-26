import Foundation
import FreeIDCore
#if canImport(ImageIO)
import ImageIO
import CoreGraphics
import CoreImage
import UniformTypeIdentifiers
#endif

// freeidctl — command-line driver for FreeIDCore.
//
// Exercises the product's domain logic with no UI, for self-test, CI regression,
// and user scripting. Zero third-party dependencies (manual arg parsing) so it builds
// offline and ships as part of the package.
//
//   freeidctl specs list [--json]
//   freeidctl specs show <id> [--json]
//   freeidctl validate <metrics.json> --spec <id> [--json] [--lang zh|en]
//   freeidctl spec-template            # print a blank FaceMetrics JSON to fill in

let args = Array(CommandLine.arguments.dropFirst())

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data(("error: " + msg + "\n").utf8))
    exit(2)
}

func flag(_ name: String) -> Bool { args.contains("--" + name) }
func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: "--" + name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

let asJSON = flag("json")
let lang = option("lang") ?? "en"

func loadLibrary() -> SpecLibrary {
    do { return try SpecLibrary.bundled() }
    catch { fail("could not load spec library: \(error)") }
}

let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tiff"]

#if canImport(ImageIO)
func loadCGImage(_ path: String) -> CGImage {
    // Honor EXIF orientation so a portrait phone photo isn't analyzed/exported sideways.
    guard let img = ImageLoading.uprightCGImage(fromFile: path) else {
        fail("cannot decode image: \(path)")
    }
    return img
}

/// Get FaceMetrics from either a FaceMetrics JSON or a real image file.
///
/// A real image yields RAW full-frame metrics, which must be reframed to the spec's crop
/// before validating (see `ExportGeometry.reprojected`) — otherwise head/eye/centering are
/// measured against the whole sensor frame and wrongly fail. A FaceMetrics JSON is treated
/// as already framed (the hand-authored / test-fixture contract) and passed through as-is.
func metricsFromInput(_ path: String, framedFor spec: PhotoSpec) -> FaceMetrics {
    let ext = (path as NSString).pathExtension.lowercased()
    if imageExtensions.contains(ext) {
        do {
            let raw = try VisionComplianceEngine().metrics(from: loadCGImage(path))
            return ExportGeometry.reprojected(raw, spec: spec)
        }
        catch { fail("vision analysis failed: \(error)") }
    }
    guard let data = FileManager.default.contents(atPath: path) else { fail("cannot read \(path)") }
    do { return try JSONDecoder().decode(FaceMetrics.self, from: data) }
    catch { fail("invalid FaceMetrics JSON: \(error)") }
}
#else
func metricsFromInput(_ path: String, framedFor spec: PhotoSpec) -> FaceMetrics {
    guard let data = FileManager.default.contents(atPath: path) else { fail("cannot read \(path)") }
    do { return try JSONDecoder().decode(FaceMetrics.self, from: data) }
    catch { fail("invalid FaceMetrics JSON: \(error)") }
}
#endif

func printJSON<T: Encodable>(_ value: T) {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let data = try? enc.encode(value), let s = String(data: data, encoding: .utf8)
    else { fail("encoding failed") }
    print(s)
}

guard let command = args.first else {
    print("""
    freeidctl — FreeID Photo core driver

    USAGE:
      freeidctl specs list [--json]
      freeidctl specs show <id> [--json]
      freeidctl validate <metrics.json> --spec <id> [--json] [--lang zh|en]
      freeidctl spec-template
    """)
    exit(0)
}

switch command {
case "specs":
    let lib = loadLibrary()
    let sub = args.count > 1 ? args[1] : "list"
    switch sub {
    case "list":
        if asJSON { printJSON(lib.specs.map(\.id)) }
        else {
            print("\(lib.specs.count) specs in \(lib.countries.count) countries:\n")
            for s in lib.specs {
                print("  \(s.id.padding(toLength: 16, withPad: " ", startingAt: 0)) "
                    + "\(s.displayName.text(forLanguage: lang))  "
                    + "[\(Int(s.outputSize.widthMM))x\(Int(s.outputSize.heightMM))mm, "
                    + "\(s.pixelWidth)x\(s.pixelHeight)px, \(s.digitalEditPolicy.rawValue)]")
            }
        }
    case "show":
        guard args.count > 2, let spec = lib.spec(id: args[2]) else { fail("unknown spec id") }
        if asJSON { printJSON(spec) }
        else {
            print("""
            \(spec.id)  —  \(spec.displayName.text(forLanguage: lang))
              country:        \(spec.country)   type: \(spec.docType.rawValue)
              output:         \(spec.outputSize.widthMM)x\(spec.outputSize.heightMM)mm @ \(spec.dpi)dpi  → \(spec.pixelWidth)x\(spec.pixelHeight)px
              head height:    \(spec.headHeight.min)–\(spec.headHeight.max)mm
              eye from bottom:\(spec.eyeLineFromBottom.min)–\(spec.eyeLineFromBottom.max)mm
              background:     \(spec.background.name.text(forLanguage: lang)) \(spec.background.hex) (ΔE≤\(spec.background.toleranceDeltaE))
              edit policy:    \(spec.digitalEditPolicy.rawValue)
              glasses:        \(spec.glasses.rawValue)
              source:         \(spec.officialSourceURL)
              last verified:  \(spec.lastVerified)
            """)
        }
    default:
        fail("unknown 'specs' subcommand: \(sub)")
    }

case "validate":
    guard args.count > 1 else { fail("usage: freeidctl validate <image|metrics.json> --spec <id>") }
    let path = args[1]
    guard let specID = option("spec") else { fail("missing --spec <id>") }
    let lib = loadLibrary()
    guard let spec = lib.spec(id: specID) else { fail("unknown spec id: \(specID)") }
    let metrics = metricsFromInput(path, framedFor: spec)
    let report = SpecValidator.validate(metrics, against: spec)
    if asJSON {
        printJSON(report)
    } else {
        print("Spec: \(spec.id) — \(spec.displayName.text(forLanguage: lang))")
        for c in report.checks {
            let mark = c.status == .pass ? "✓" : (c.status == .warn ? "!" : "✗")
            print("  \(mark) \(c.title.text(forLanguage: lang)): \(c.detail.text(forLanguage: lang))")
        }
        print("\nResult: \(report.overall.rawValue.uppercased()) "
            + "(\(report.isCompliant ? "compliant" : "not compliant"))")
    }
    exit(report.isCompliant ? 0 : 1)

#if canImport(ImageIO)
case "export":
    guard args.count > 1 else {
        fail("usage: freeidctl export <image> --spec <id> --out <path> [--replace-bg] [--bg #RRGGBB] "
           + "[--sheet [--paper 4x6|5x7|a4]]")
    }
    let path = args[1]
    guard let specID = option("spec") else { fail("missing --spec <id>") }
    guard let outPath = option("out") else { fail("missing --out <path>") }
    let lib = loadLibrary()
    guard let spec = lib.spec(id: specID) else { fail("unknown spec id: \(specID)") }
    let cg = loadCGImage(path)
    let metrics: FaceMetrics
    do { metrics = try VisionComplianceEngine().metrics(from: cg) }
    catch { fail("vision analysis failed: \(error)") }
    if metrics.faceCount != 1 { fail("expected exactly one face, found \(metrics.faceCount)") }

    let pipeline = ExportPipeline()
    let opts = ExportPipeline.Options(replaceBackground: flag("replace-bg"), backgroundHex: option("bg"))
    do {
        var out = try pipeline.export(image: cg, spec: spec, metrics: metrics, options: opts)
        var note = ""
        if flag("sheet") {
            let name = (option("paper") ?? "4x6").lowercased()
            let paper: ExportPipeline.PrintPaper
            switch name {
            case "4x6", "6x4": paper = .fourBySix
            case "5x7", "7x5": paper = .fiveBySeven
            case "a4":         paper = .a4
            default: fail("bad --paper (use 4x6, 5x7 or a4)")
            }
            guard let sheet = pipeline.printSheet(photo: out, spec: spec, paper: paper) else {
                fail("print sheet render failed")
            }
            out = sheet.image
            note = " — \(sheet.copies) copies on \(name)"
        }
        let data = (outPath as NSString).pathExtension.lowercased() == "png"
            ? try pipeline.pngData(out) : try pipeline.jpegData(out, dpi: spec.dpi)
        try data.write(to: URL(fileURLWithPath: outPath))
        print("wrote \(out.width)x\(out.height)px @\(spec.dpi)dpi → \(outPath)\(note)")
    } catch { fail("export failed: \(error)") }

case "measure":
    // Dump the FaceMetrics measured from a real image. Useful on its own, and it lets the
    // app's measurements be captured here and replayed where Vision is unavailable.
    guard args.count > 1 else { fail("usage: freeidctl measure <image>") }
    let cg = loadCGImage(args[1])
    do { printJSON(try VisionComplianceEngine().metrics(from: cg)) }
    catch { fail("vision analysis failed: \(error)") }

case "bgreplace":
    // Replace the background only — keep the original framing/size, no crop to a spec.
    guard args.count > 1 else { fail("usage: freeidctl bgreplace <image> --out <path> [--bg #RRGGBB]") }
    let path = args[1]
    guard let outPath = option("out") else { fail("missing --out <path>") }
    let hex = option("bg") ?? "#FFFFFF"
    let cg = loadCGImage(path)
    let pipeline = ExportPipeline()
    do {
        let ci = try pipeline.replaceBackground(of: cg, with: hex)
        guard let out = CIContext().createCGImage(ci, from: ci.extent) else { fail("render failed") }
        let data = (outPath as NSString).pathExtension.lowercased() == "png"
            ? try pipeline.pngData(out) : try pipeline.jpegData(out)
        try data.write(to: URL(fileURLWithPath: outPath))
        print("wrote \(out.width)x\(out.height)px → \(outPath)")
    } catch { fail("bgreplace failed: \(error)") }

case "customexport":
    // Export to an arbitrary physical size (mm) with ID-photo head framing + optional bg.
    //   freeidctl customexport <image> --mm 40x60 --out <path> [--bg #RRGGBB]
    guard args.count > 1 else { fail("usage: freeidctl customexport <image> --mm 40x60 --out <path> [--bg #RRGGBB]") }
    let path = args[1]
    guard let outPath = option("out") else { fail("missing --out <path>") }
    let dims = (option("mm") ?? "40x60").lowercased().replacingOccurrences(of: "*", with: "x").split(separator: "x")
    guard dims.count == 2, let w = Double(dims[0]), let h = Double(dims[1]), w > 0, h > 0 else { fail("bad --mm (use e.g. 40x60)") }
    let bg = option("bg")
    let cg = loadCGImage(path)
    let metrics: FaceMetrics
    do { metrics = try VisionComplianceEngine().metrics(from: cg) } catch { fail("vision analysis failed: \(error)") }
    if metrics.faceCount != 1 { fail("expected exactly one face, found \(metrics.faceCount)") }
    let spec = PhotoSpec(
        id: "custom-\(Int(w))x\(Int(h))", country: "", docType: .general,
        displayName: LocalizedText(en: "\(Int(w))x\(Int(h))mm", zh: "\(Int(w))x\(Int(h))mm"),
        outputSize: PhysicalSize(widthMM: w, heightMM: h), dpi: 300,
        headHeight: RangeMM(min: h * 0.58, max: h * 0.69), eyeLineFromBottom: RangeMM(min: h * 0.55, max: h * 0.62),
        background: BackgroundRule(name: LocalizedText(en: "White", zh: "白色"), hex: bg ?? "#FFFFFF", toleranceDeltaE: 12, minUniformity: 0.85),
        digitalEditPolicy: .allowed, expression: ExpressionRule(neutral: true, mouthClosed: true, eyesOpen: true),
        glasses: .allowedNoGlare, fileSpec: nil, officialSourceURL: "", lastVerified: "")
    let pipeline2 = ExportPipeline()
    do {
        let out = try pipeline2.export(image: cg, spec: spec, metrics: metrics, options: .init(replaceBackground: bg != nil, backgroundHex: bg))
        let data = (outPath as NSString).pathExtension.lowercased() == "png" ? try pipeline2.pngData(out) : try pipeline2.jpegData(out)
        try data.write(to: URL(fileURLWithPath: outPath))
        print("wrote \(out.width)x\(out.height)px (\(Int(w))x\(Int(h))mm @300dpi) → \(outPath)")
    } catch { fail("customexport failed: \(error)") }

#endif
case "spec-template":
    let blank = FaceMetrics(
        imageWidth: 1200, imageHeight: 1200, faceCount: 1,
        crownY: 0.10, chinY: 0.70, eyeLineY: 0.38, faceCenterX: 0.50,
        rollDegrees: 0, yawDegrees: 0, pitchDegrees: 0,
        eyesOpen: true, mouthClosed: true, neutralExpression: true,
        backgroundUniformity: 0.95, backgroundMeanHex: "#FFFFFF",
        glassesDetected: false, glareOnGlasses: false, brightness: 0.6
    )
    printJSON(blank)

default:
    fail("unknown command: \(command)")
}
