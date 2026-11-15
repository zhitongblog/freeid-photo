import XCTest
@testable import FreeIDCore

final class SpecLibraryTests: XCTestCase {

    func testLibraryLoadsBundledSpecs() throws {
        let lib = try SpecLibrary.bundled()
        XCTAssertGreaterThanOrEqual(lib.specs.count, 24, "expected the expanded 24-spec set")
        XCTAssertGreaterThanOrEqual(lib.countries.count, 12, "expected 12 countries/regions")
        XCTAssertNotNil(lib.spec(id: "us-passport"))
        XCTAssertNotNil(lib.spec(id: "cn-1inch"))
        XCTAssertNotNil(lib.spec(id: "ca-passport"))
        XCTAssertNotNil(lib.spec(id: "cn-idcard"))
        XCTAssertNotNil(lib.spec(id: "cn-driver"))
        XCTAssertNotNil(lib.spec(id: "cn-social"))
        XCTAssertNotNil(lib.spec(id: "cn-exam"))
        XCTAssertNotNil(lib.spec(id: "cn-hkmo"))
        XCTAssertNotNil(lib.spec(id: "hk-passport"))
        XCTAssertNotNil(lib.spec(id: "tw-passport"))
        XCTAssertNotNil(lib.spec(id: "jp-resume"))
        let grad = try XCTUnwrap(lib.spec(id: "cn-grad"))
        XCTAssertEqual(grad.pixelWidth, 480)
        XCTAssertEqual(grad.pixelHeight, 640)
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

    func testCustomSpecDerivesValidRangesAndFileSpec() {
        let custom = PhotoSpec.custom(widthMM: 33, heightMM: 48, minKB: 20, maxKB: 100)
        XCTAssertEqual(custom.id, "custom-33x48")
        XCTAssertEqual(custom.outputSize.widthMM, 33)
        XCTAssertEqual(custom.outputSize.heightMM, 48)
        XCTAssertLessThan(custom.headHeight.min, custom.headHeight.max)
        XCTAssertLessThan(custom.eyeLineFromBottom.min, custom.eyeLineFromBottom.max)
        XCTAssertEqual(custom.fileSpec?.minKB, 20)
        XCTAssertEqual(custom.fileSpec?.maxKB, 100)
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
