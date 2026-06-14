#if canImport(CoreImage) && canImport(ImageIO)
import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import FreeIDCore

/// Verifies the EXIF-orientation fix: a portrait phone capture stores landscape pixels plus
/// an orientation tag, and we must honor that tag or the photo is analyzed/exported sideways.
final class ImageOrientationTests: XCTestCase {

    /// Encode a `w × h` solid image as JPEG, tagging it with the given EXIF orientation.
    private func jpeg(w: Int, h: Int, orientation: Int) -> Data {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let cg = ctx.makeImage()!
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cg, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return out as Data
    }

    func testOrientation1IsUnchanged() throws {
        let data = jpeg(w: 200, h: 100, orientation: 1)
        let img = try XCTUnwrap(ImageLoading.uprightCGImage(from: data))
        XCTAssertEqual(img.width, 200)
        XCTAssertEqual(img.height, 100)
    }

    /// Orientation 6 ("rotate 90°") must swap width/height — landscape pixels become the
    /// upright portrait the user actually shot. This is the exact bug being fixed.
    func testOrientation6SwapsToPortrait() throws {
        let data = jpeg(w: 200, h: 100, orientation: 6)
        let img = try XCTUnwrap(ImageLoading.uprightCGImage(from: data))
        XCTAssertEqual(img.width, 100, "width/height should swap after applying 90° orientation")
        XCTAssertEqual(img.height, 200)
    }

    func testOrientation8SwapsToPortrait() throws {
        let data = jpeg(w: 200, h: 100, orientation: 8) // rotate 270°
        let img = try XCTUnwrap(ImageLoading.uprightCGImage(from: data))
        XCTAssertEqual(img.width, 100)
        XCTAssertEqual(img.height, 200)
    }
}
#endif
