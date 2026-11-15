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
.build/debug/freeidctl measure face.jpg                    # FaceMetrics measured from a real image
.build/debug/freeidctl export face.jpg --spec cn-1inch --replace-bg --out out.jpg
.build/debug/freeidctl export face.jpg --spec cn-1inch --out sheet.jpg --sheet --paper 4x6
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
carries `officialSourceURL` and `lastVerified`. 24 specs across 12 countries & regions:

| Country / Region | Specs | Edit policy |
|---|---|---|
| China | 1-inch, 2-inch, ID card, driver license, social security, exam (CET/teacher/civil), CHSI graduation (480×640), HK/Macau/TW travel permit, passport, visa | allowed |
| Hong Kong | HKSAR passport / Home Return Permit (40×50mm) | allowed |
| Taiwan | passport / entry permit (35×45mm) | allowed |
| US | passport, visa | strict (no AI/edits) |
| Canada | passport (50×70mm) | strict |
| UK | passport | strict |
| Australia | passport | strict |
| South Korea | passport | strict |
| Schengen / EU | visa | allowed |
| Japan | visa (45×45mm), resume / residence card (30×40mm) | allowed |
| India | passport (630×810px), e-visa 2×2 | allowed |
| Singapore | passport (400×514px) | allowed |

Dimensions are verified against official government sources (linked per spec). Where a
government does not publish an explicit eye-line position, that range is derived from the
head-height rule and the photo layout — re-confirm against the live official checklist
before relying on it for a submission, since requirements change.

## `freeid-mcp` — MCP server

Exposes the core over Model Context Protocol (stdio) so any LLM can drive it.
Read-only by default; `--allow-write` enables `export_photo`.

```bash
swift build
.build/debug/freeid-mcp --allow-write   # tools: list_specs, get_spec, validate_photo, export_photo
```

`export_photo` takes an optional `paper` (`4x6` / `5x7` / `a4`) to tile copies onto a print
sheet instead of writing a single photo.

## The iOS app

Generated from `project.yml` with [xcodegen](https://github.com/yonaskolb/XcodeGen)
(the `.xcodeproj` is not committed):

```bash
xcodegen generate
xcodebuild -project FreeIDPhoto.xcodeproj -scheme FreeIDPhoto \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

The app shows a live viewfinder with a guide frame and a one-line coach. You can also pick a
photo you already have from the library — the same pipeline runs on it, and anything the crop
can't fix (pose, eyes, glasses, an unusable background on a strict spec) is listed on the
result screen before you submit. Finished photos can be tiled onto a 4×6″ / 5×7″ / A4 print
sheet with cut guides, stamped with the spec's DPI so a lab prints them at true size.

**Debug harness.** Vision is unavailable in the iOS Simulator (`E5RT is not supported`), so
DEBUG builds accept launch arguments that drive the import path without it:

```bash
freeidctl measure face.jpg > metrics.json   # capture real measurements on macOS
xcrun simctl launch <device> com.freeidphoto.app \
  -import-photo <path/to/face.jpg> -metrics <path/to/metrics.json> \
  -spec us-passport -show-print-sheet
```

Diagnostics land in `Documents/harness.log` inside the app container. None of this is
compiled into a Release build.

## Status

- [x] FreeIDCore: spec model, library, validator, color math
- [x] freeidctl CLI: specs / validate (image or JSON) / export / print sheet
- [x] VisionComplianceEngine: FaceMetrics from a real image (face landmarks, crown segmentation, glasses & lens glare, cheek lighting symmetry, smile check)
- [x] ExportPipeline: crop / align / background replace / portrait brightness & skin refinement / KB size window / print sheet
- [x] FreeIDApp: SwiftUI live-compliance viewfinder + spec picker + result spec switcher + local history originals
- [x] freeid-mcp: MCP server (list/get/validate/export, single photo or print sheet)
- [x] Photo-library import & local history originals: use a photo you already have or re-export a previous shot in 1 tap
- [x] Print sheets: 4×6″ / 5×7″ / A4, centred with cut guides, DPI stamped into the file
- [x] 24 specs across 12 countries/regions, dimensions verified against official sources
- [x] App Store Connect automation & localized store assets across all 8 languages (`en-US`, `zh-Hans`, `zh-Hant`, `ja`, `ko`, `fr-FR`, `de-DE`, `it`)
