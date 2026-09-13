import XCTest
@testable import ScreenScan

final class QRDecoderTests: XCTestCase {
    func testDecodesURLPayload() async throws {
        let image = try QRFixtures.image(payload: "https://example.com/scan")

        let results = try await QRDecoder.decode(image)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.payload, "https://example.com/scan")
        XCTAssertEqual(results.first?.openableURL?.absoluteString, "https://example.com/scan")
    }

    func testDecodesPlainTextPayload() async throws {
        let image = try QRFixtures.image(payload: "Product-42")

        let results = try await QRDecoder.decode(image)

        XCTAssertEqual(results.first?.payload, "Product-42")
        XCTAssertNil(results.first?.openableURL, "Plain text must not offer an Open button")
    }

    func testDecodesEveryCodeInTheImage() async throws {
        let image = try QRFixtures.composite(payloads: ["https://example.com/one", "second-payload"])

        let results = try await QRDecoder.decode(image)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(Set(results.map(\.payload)),
                       ["https://example.com/one", "second-payload"])
    }

    func testBlankImageReturnsNoResultsRatherThanThrowing() async throws {
        let results = try await QRDecoder.decode(try QRFixtures.blank())

        XCTAssertTrue(results.isEmpty)
    }
}
