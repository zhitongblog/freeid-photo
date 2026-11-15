import Foundation
import FreeIDCore
#if canImport(ImageIO)
import ImageIO
import CoreGraphics
#endif

// freeid-mcp — Model Context Protocol server exposing FreeIDCore over stdio.
//
// Lets Claude (or any MCP client) list specs, inspect them, validate a photo, and
// (with --allow-write) export a compliant photo — driving the product like an external
// client. Read-only by default; export is gated behind --allow-write per the project's
// CLI/MCP convention.
//
// Transport: newline-delimited JSON-RPC 2.0 over stdin/stdout (MCP stdio transport).

let allowWrite = CommandLine.arguments.contains("--allow-write")
let library = (try? SpecLibrary.bundled()) ?? SpecLibrary(specs: [])

// MARK: - JSON-RPC plumbing

func send(_ object: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: object),
          let line = String(data: data, encoding: .utf8) else { return }
    print(line)
    fflush(stdout)
}

func result(id: Any?, _ value: Any) {
    send(["jsonrpc": "2.0", "id": id ?? NSNull(), "result": value])
}

func error(id: Any?, code: Int, message: String) {
    send(["jsonrpc": "2.0", "id": id ?? NSNull(), "error": ["code": code, "message": message]])
}

func textContent(_ s: String) -> [String: Any] {
    ["content": [["type": "text", "text": s]]]
}

func jsonString<T: Encodable>(_ v: T) -> String {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return (try? enc.encode(v)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
}

// MARK: - Tool definitions

func toolList() -> [[String: Any]] {
    var tools: [[String: Any]] = [
        ["name": "list_specs",
         "description": "List all available ID-photo specs (country + document type).",
         "inputSchema": ["type": "object", "properties": [:]]],
        ["name": "get_spec",
         "description": "Get the full definition of one spec by id.",
         "inputSchema": ["type": "object",
                         "properties": ["id": ["type": "string"]],
                         "required": ["id"]]],
        ["name": "validate_photo",
         "description": "Analyze an image file and validate it against a spec. Returns a compliance report.",
         "inputSchema": ["type": "object",
                         "properties": ["path": ["type": "string"], "spec": ["type": "string"]],
                         "required": ["path", "spec"]]],
    ]
    if allowWrite {
        tools.append(
            ["name": "export_photo",
             "description": "Crop/align/resize an image to a spec and write the output file. Set replaceBackground only for edit-allowed specs. Set paper to tile copies onto a print sheet instead of writing a single photo.",
             "inputSchema": ["type": "object",
                             "properties": [
                                "path": ["type": "string"],
                                "spec": ["type": "string"],
                                "out": ["type": "string"],
                                "replaceBackground": ["type": "boolean"],
                                "brightnessBoost": ["type": "number"],
                                "skinSmoothing": ["type": "number"],
                                "paper": ["type": "string", "enum": ["4x6", "5x7", "a4"]]],
                             "required": ["path", "spec", "out"]]])
    }
    return tools
}

// MARK: - Tool dispatch

func callTool(name: String, args: [String: Any]) -> (text: String, isError: Bool) {
    switch name {
    case "list_specs":
        let rows = library.specs.map { ["id": $0.id, "name": $0.displayName.en,
                                        "country": $0.country, "policy": $0.digitalEditPolicy.rawValue] }
        return (jsonString(rows), false)

    case "get_spec":
        guard let id = args["id"] as? String, let spec = library.spec(id: id) else {
            return ("unknown spec id", true)
        }
        return (jsonString(spec), false)

    case "validate_photo":
        guard let path = args["path"] as? String, let specID = args["spec"] as? String,
              let spec = library.spec(id: specID) else { return ("missing path/spec or unknown spec", true) }
        #if canImport(ImageIO)
        guard let cg = ImageLoading.uprightCGImage(fromFile: path) else {  // honor EXIF orientation
            return ("cannot read image: \(path)", true)
        }
        do {
            // Raw full-frame metrics must be reframed to the spec's crop before validating,
            // or head/eye/centering fail against the whole frame. See ExportGeometry.reprojected.
            let metrics = try VisionComplianceEngine().metrics(from: cg)
            let framed = ExportGeometry.reprojected(metrics, spec: spec)
            let report = SpecValidator.validate(framed, against: spec)
            return (jsonString(report), false)
        } catch { return ("vision failed: \(error)", true) }
        #else
        return ("image analysis unavailable on this platform", true)
        #endif

    case "export_photo" where allowWrite:
        guard let path = args["path"] as? String, let specID = args["spec"] as? String,
              let out = args["out"] as? String, let spec = library.spec(id: specID) else {
            return ("missing path/spec/out or unknown spec", true)
        }
        #if canImport(ImageIO)
        guard let cg = ImageLoading.uprightCGImage(fromFile: path) else {  // honor EXIF orientation
            return ("cannot read image", true)
        }
        do {
            let metrics = try VisionComplianceEngine().metrics(from: cg)
            guard metrics.faceCount == 1 else { return ("expected one face, found \(metrics.faceCount)", true) }
            let pipeline = ExportPipeline()
            let opts = ExportPipeline.Options(
                replaceBackground: (args["replaceBackground"] as? Bool) ?? false,
                brightnessBoost: (args["brightnessBoost"] as? Double) ?? 0.0,
                skinSmoothing: (args["skinSmoothing"] as? Double) ?? 0.0)
            var outImage = try pipeline.export(image: cg, spec: spec, metrics: metrics, options: opts)
            var note = ""
            if let paperName = args["paper"] as? String {
                let papers: [String: ExportPipeline.PrintPaper] = [
                    "4x6": .fourBySix, "5x7": .fiveBySeven, "a4": .a4,
                ]
                guard let paper = papers[paperName.lowercased()] else {
                    return ("unknown paper \(paperName) — use 4x6, 5x7 or a4", true)
                }
                guard let sheet = pipeline.printSheet(photo: outImage, spec: spec, paper: paper) else {
                    return ("print sheet render failed", true)
                }
                outImage = sheet.image
                note = " (\(sheet.copies) copies on \(paperName))"
            }
            let isSheet = args["paper"] != nil
            let data = (out as NSString).pathExtension.lowercased() == "png"
                ? try pipeline.pngData(outImage)
                : (isSheet ? try pipeline.jpegData(outImage, dpi: spec.dpi) : try pipeline.jpegData(outImage, spec: spec))
            try data.write(to: URL(fileURLWithPath: out))
            return ("wrote \(outImage.width)x\(outImage.height)px @\(spec.dpi)dpi (\(data.count / 1024)KB) to \(out)\(note)", false)
        } catch { return ("export failed: \(error)", true) }
        #else
        return ("export unavailable on this platform", true)
        #endif

    default:
        return ("unknown tool: \(name)", true)
    }
}

// MARK: - Main loop

while let line = readLine(strippingNewline: true) {
    if line.isEmpty { continue }
    guard let data = line.data(using: .utf8),
          let msg = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
        continue
    }
    let id = msg["id"]
    guard let method = msg["method"] as? String else { continue }

    switch method {
    case "initialize":
        result(id: id, [
            "protocolVersion": "2024-11-05",
            "capabilities": ["tools": [:]],
            "serverInfo": ["name": "freeid-mcp", "version": "0.1.0",
                           "writable": allowWrite],
        ])
    case "notifications/initialized":
        break // no response to notifications
    case "tools/list":
        result(id: id, ["tools": toolList()])
    case "tools/call":
        let params = msg["params"] as? [String: Any] ?? [:]
        let name = params["name"] as? String ?? ""
        let args = params["arguments"] as? [String: Any] ?? [:]
        let (text, isError) = callTool(name: name, args: args)
        var content = textContent(text)
        content["isError"] = isError
        result(id: id, content)
    case "ping":
        result(id: id, [:])
    default:
        if id != nil { error(id: id, code: -32601, message: "method not found: \(method)") }
    }
}
