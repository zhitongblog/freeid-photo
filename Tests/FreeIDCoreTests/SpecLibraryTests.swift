import XCTest
@testable import FreeIDCore

final class SpecLibraryTests: XCTestCase {

    func testLibraryLoadsBundledSpecs() throws {
        let lib = try SpecLibrary.bundled()
        XCTAssertGreaterThanOrEqual(lib.specs.count, 7, "expected the seed spec set")
        XCTAssertNotNil(lib.spec(id: "us-passport"))
        XCTAssertNotNil(lib.spec(id: "cn-1inch"))
    }

    func testSpecIDsAreUnique() throws {
        let ids = try SpecLibrary.bundled().specs.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "spec ids must be unique")
    }

    func testPixelDimensionsDeriveFromMM() throws {
        let s = try XCTUnwrap(try SpecLibrary.bundled().spec(id: "us-passport"))
        // 51mm / 25.4 * 300dpi = 602px
        XCTAssertEqual(s.pixelWidth, 602)
        XCTAssertEqual(s.pixelHeight, 602)
    }

    func testEverySpecHasOfficialSourceAndVerificationDate() throws {
        for s in try SpecLibrary.bundled().specs {
            XCTAssertTrue(s.officialSourceURL.hasPrefix("http"), "\(s.id) needs a source URL")
            XCTAssertFalse(s.lastVerified.isEmpty, "\(s.id) needs a lastVerified date")
        }
    }

    func testRangesAreWellFormed() throws {
        for s in try SpecLibrary.bundled().specs {
            XCTAssertLessThan(s.headHeight.min, s.headHeight.max, "\(s.id) headHeight range")
            XCTAssertLessThan(s.eyeLineFromBottom.min, s.eyeLineFromBottom.max, "\(s.id) eyeLine range")
            XCTAssertLessThanOrEqual(s.headHeight.max, s.outputSize.heightMM, "\(s.id) head taller than photo")
        }
    }

    func testStrictPolicyAppliesToUSPassport() throws {
        let s = try XCTUnwrap(try SpecLibrary.bundled().spec(id: "us-passport"))
        XCTAssertEqual(s.digitalEditPolicy, .strict)
    }
}

final class ColorMathTests: XCTestCase {
    func testIdenticalColorsHaveZeroDeltaE() {
        XCTAssertEqual(ColorMath.deltaE("#FFFFFF", "#FFFFFF"), 0, accuracy: 0.001)
    }
    func testWhiteVsBlueIsLarge() {
        XCTAssertGreaterThan(ColorMath.deltaE("#FFFFFF", "#3366CC"), 30)
    }
    func testNearWhitesAreClose() {
        XCTAssertLessThan(ColorMath.deltaE("#FFFFFF", "#FBFBFB"), 5)
    }
    func testMalformedHexIsInfinite() {
        XCTAssertEqual(ColorMath.deltaE("nope", "#FFFFFF"), .infinity)
    }
}
