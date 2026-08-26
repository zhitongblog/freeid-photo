#if canImport(CoreImage) && canImport(Vision)
import XCTest
import CoreGraphics
@testable import FreeIDCore

/// The print sheet is what a photo lab actually prints, so its physical geometry has to be
/// exact: wrong pixel dimensions at the spec's DPI and the lab prints ID photos at the wrong
/// size, which is invisible on screen and only discovered after paying for the prints.
final class PrintSheetTests: XCTestCase {

    private let pipeline = ExportPipeline()

    /// A 25×35mm 一寸 at 300dpi — the most common sheet subject.
    private func oneInchSpec() throws -> PhotoSpec {
        let lib = try SpecLibrary.bundled()
        return try XCTUnwrap(lib.spec(id: "cn-1inch"))
    }

    private func solidPhoto(_ spec: PhotoSpec) -> CGImage {
        let ctx = CGContext(data: nil, width: spec.pixelWidth, height: spec.pixelHeight,
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: spec.pixelWidth, height: spec.pixelHeight))
        return ctx.makeImage()!
    }

    /// Each paper must come out at its true physical size in pixels at the spec's DPI:
    /// 6×4in → 1800×1200, 7×5in → 2100×1500, A4 → 2480×3508.
    func testSheetPixelSizeMatchesPaperAtSpecDPI() throws {
        let spec = try oneInchSpec()
        let photo = solidPhoto(spec)
        let expected: [ExportPipeline.PrintPaper: (Int, Int)] = [
            .fourBySix: (1800, 1200), .fiveBySeven: (2100, 1500), .a4: (2480, 3508),
        ]
        for (paper, size) in expected {
            let sheet = try XCTUnwrap(pipeline.printSheet(photo: photo, spec: spec, paper: paper))
            XCTAssertEqual(sheet.image.width, size.0, "\(paper) width")
            XCTAssertEqual(sheet.image.height, size.1, "\(paper) height")
        }
    }

    /// The advertised copy count must be what actually gets drawn — it's the number the user
    /// picks the paper on.
    func testCopyCountMatchesWhatFits() throws {
        let spec = try oneInchSpec()
        let photo = solidPhoto(spec)
        for paper in ExportPipeline.PrintPaper.allCases {
            let sheet = try XCTUnwrap(pipeline.printSheet(photo: photo, spec: spec, paper: paper))
            XCTAssertEqual(sheet.copies, pipeline.copiesPerSheet(spec: spec, paper: paper))
            XCTAssertGreaterThan(sheet.copies, 0)
        }
        // A 一寸 on 4×6 is the canonical case: 5 across, 2 down.
        XCTAssertEqual(pipeline.copiesPerSheet(spec: spec, paper: .fourBySix), 10)
    }

    /// The block of photos is centred, so the leftover paper is split evenly instead of
    /// piling onto two edges. Checked by confirming the margins on opposite edges match.
    func testPhotoBlockIsCentred() throws {
        let spec = try oneInchSpec()
        let sheet = try XCTUnwrap(
            pipeline.printSheet(photo: solidPhoto(spec), spec: spec, paper: .fourBySix))
        let img = sheet.image
        let width = img.width, height = img.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let ctx = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: width, height: height))

        /// Is this pixel part of a photo (the blue fill), rather than paper or a cut line?
        func isPhoto(x: Int, y: Int) -> Bool {
            let i = y * bytesPerRow + x * 4
            return pixels[i] < 128 && pixels[i + 2] > 128
        }
        // Bounding box over the whole sheet, not a single scan line: a mid-height row can
        // fall in the gap between two rows of photos and find nothing.
        var minX = width, maxX = -1, minY = height, maxY = -1
        for y in 0..<height {
            for x in 0..<width where isPhoto(x: x, y: y) {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        XCTAssertGreaterThanOrEqual(maxX, 0, "no photo pixels found on the sheet")

        let leftMargin = minX
        let rightMargin = width - 1 - maxX
        let topMargin = minY
        let bottomMargin = height - 1 - maxY
        // Allow a couple of pixels for the integer split and the hairline cut guides.
        XCTAssertLessThanOrEqual(abs(leftMargin - rightMargin), 3, "horizontal margins differ")
        XCTAssertLessThanOrEqual(abs(topMargin - bottomMargin), 3, "vertical margins differ")
    }
}
#endif
