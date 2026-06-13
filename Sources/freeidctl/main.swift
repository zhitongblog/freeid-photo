import Foundation
import FreeIDCore
#if canImport(ImageIO)
import ImageIO
import CoreGraphics
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
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
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
    guard args.count > 1 else { fail("usage: freeidctl export <image> --spec <id> --out <path> [--replace-bg] [--sheet]") }
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
    let opts = ExportPipeline.Options(replaceBackground: flag("replace-bg"))
    do {
        var out = try pipeline.export(image: cg, spec: spec, metrics: metrics, options: opts)
        if flag("sheet"), let sheet = pipeline.printSheet(photo: out, spec: spec) { out = sheet }
        let data = (outPath as NSString).pathExtension.lowercased() == "png"
            ? try pipeline.pngData(out) : try pipeline.jpegData(out)
        try data.write(to: URL(fileURLWithPath: outPath))
        print("wrote \(out.width)x\(out.height)px → \(outPath)")
    } catch { fail("export failed: \(error)") }

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
