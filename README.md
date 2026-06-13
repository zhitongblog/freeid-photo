# FreeID Photo

Free, on-device, global ID-photo app for iPhone. Shoot a compliant passport / visa /
ID photo with real-time guidance — no watermark, no paywall, no account, nothing
uploaded.

> **Why another one?** The "free passport photo" category is full of apps that let you
> edit the perfect photo, then slap an unremovable watermark on it and charge $6-9 to
> download. FreeID Photo is free all the way through, runs entirely on your device, and
> guides you to a photo that is *already compliant* instead of editing one that isn't.

## The core idea: guide, don't fake

In 2026 the US enforces zero tolerance for digitally altered passport photos (≈15-20%
of app photos get rejected). So **whether digital editing is allowed is a per-country
rule**, carried in each spec as `digitalEditPolicy`:

- `strict` (US, UK passport): no AI background replacement. We guide you to shoot
  against a real, even background and only crop / rotate / resize.
- `allowed` (China, Japan, Schengen): background replacement and color normalization
  are offered.

The live viewfinder unlocks the shutter only when every requirement for the chosen spec
is green, so the safe path — a real, already-compliant photo — works for every country.

## Architecture

```
FreeIDCore  (pure Swift, no UI, no camera)  ── shared by ───┐
  ├── SpecLibrary     bundled per-country JSON specs        │
  ├── FaceMetrics     platform-agnostic measurements        ├── FreeIDApp   (SwiftUI)
  ├── SpecValidator   metrics × spec → ComplianceReport     ├── freeidctl   (CLI)
  └── ColorMath       sRGB→Lab ΔE background color check     └── freeid-mcp  (MCP, planned)
```

`SpecValidator` is decoupled from Apple Vision, so it is 100% unit-testable with
synthetic metrics (no camera, no device). Vision produces `FaceMetrics`; the validator
turns metrics + a spec into a pass/warn/fail report.

## `freeidctl` — command-line driver

Drives the domain logic with no UI, for self-test, CI, and scripting.

```bash
swift build
.build/debug/freeidctl specs list
.build/debug/freeidctl specs show us-passport
.build/debug/freeidctl spec-template > photo.json          # blank FaceMetrics to fill
.build/debug/freeidctl validate photo.json --spec us-passport --lang zh
```

`validate` exits 0 if compliant, 1 if not — usable as a CI gate.

## Tests

```bash
swift test
```

Covers a compliant configuration for every bundled spec plus each individual failure
mode (head size, centering, pose, eyes, mouth, lighting, glasses, background uniformity)
and the per-country background-color policy.

## Spec data

Specs live as one JSON file per country+document in `Sources/FreeIDCore/Specs/`. Each
carries `officialSourceURL` and `lastVerified`. **The seed values are transcribed from
public sources and must be verified against official government tables before release.**

## `freeid-mcp` — MCP server

Exposes the core over Model Context Protocol (stdio) so any LLM can drive it.
Read-only by default; `--allow-write` enables `export_photo`.

```bash
swift build
.build/debug/freeid-mcp --allow-write   # tools: list_specs, get_spec, validate_photo, export_photo
```

## The iOS app

Generated from `project.yml` with [xcodegen](https://github.com/yonaskolb/XcodeGen)
(the `.xcodeproj` is not committed):

```bash
xcodegen generate
xcodebuild -project FreeIDPhoto.xcodeproj -scheme FreeIDPhoto \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

The app shows a live viewfinder with a guide frame and the compliance HUD; the shutter
unlocks only when every check for the selected spec is green.

## Status

- [x] FreeIDCore: spec model, library, validator, color math (34 tests)
- [x] freeidctl CLI: specs / validate (image or JSON) / export / print sheet
- [x] VisionComplianceEngine: FaceMetrics from a real image (face landmarks + segmentation)
- [x] ExportPipeline: crop / align / background replace / size normalization / print sheet
- [x] FreeIDApp: SwiftUI live-compliance viewfinder + spec picker (builds & runs on Simulator)
- [x] freeid-mcp: MCP server (list/get/validate/export)
- [ ] Verify each bundled spec's numbers against the official government source
- [ ] On-device tuning: crown/hairline calibration, glasses/glare detection, live capture (/ios-qa)
