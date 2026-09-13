import XCTest
@testable import ScreenScan

final class ScanResultTests: XCTestCase {
    private func result(_ payload: String) -> ScanResult {
        ScanResult(payload: payload, boundingBox: .zero)
    }

    func testWebURLsAreOpenable() {
        XCTAssertEqual(result("https://example.com").openableURL?.absoluteString, "https://example.com")
        XCTAssertEqual(result("http://example.com/path?q=1").openableURL?.absoluteString,
                       "http://example.com/path?q=1")
    }

    func testSurroundingWhitespaceIsIgnored() {
        XCTAssertNotNil(result("  https://example.com\n").openableURL)
    }

    func testPlainTextIsNotOpenable() {
        // `URL(string:)` alone would happily build something out of these.
        XCTAssertNil(result("Product-42").openableURL)
        XCTAssertNil(result("hello world").openableURL)
        XCTAssertNil(result("").openableURL)
    }

    func testWebURLWithoutHostIsNotOpenable() {
        XCTAssertNil(result("https://").openableURL)
    }

    func testMailtoAndTelAreOpenable() {
        XCTAssertNotNil(result("mailto:someone@example.com").openableURL)
        XCTAssertNotNil(result("tel:+15555550123").openableURL)
    }

    func testSchemeWithNoBodyIsNotOpenable() {
        XCTAssertNil(result("mailto:").openableURL)
    }

    func testUnsafeOrNonNavigableSchemesAreTextOnly() {
        // A QR code is untrusted input; only the allowlisted schemes reach NSWorkspace.
        XCTAssertNil(result("javascript:alert(1)").openableURL)
        XCTAssertNil(result("WIFI:S:MyNetwork;T:WPA;P:secret;;").openableURL)
        XCTAssertNil(result("file:///etc/passwd").openableURL)
        XCTAssertNil(result("someapp://do-something-destructive").openableURL)
    }

    func testSchemeMatchingIsCaseInsensitive() {
        XCTAssertNotNil(result("HTTPS://example.com").openableURL)
    }
}
