import CoreGraphics
import Foundation

/// One QR code decoded out of a captured region.
struct ScanResult: Identifiable, Hashable {
    let id: UUID
    /// The decoded payload, exactly as it appeared in the code.
    let payload: String
    /// Vision's normalized bounding box within the captured image (origin bottom-left).
    let boundingBox: CGRect

    init(id: UUID = UUID(), payload: String, boundingBox: CGRect) {
        self.id = id
        self.payload = payload
        self.boundingBox = boundingBox
    }

    /// Schemes we are willing to hand to `NSWorkspace.shared.open`.
    ///
    /// A QR code is untrusted input from the physical world, and opening an arbitrary
    /// scheme can trigger an action in some other app. Anything outside this list —
    /// `javascript:`, `WIFI:`, custom app schemes — stays copy-only.
    static let openableSchemes: Set<String> = ["http", "https", "mailto", "tel"]

    /// The payload as a link, or `nil` if it should be treated as plain text.
    ///
    /// `URL(string:)` alone is not enough: it happily builds a nonsensical URL out of a
    /// bare string like `Product-42`, so a scheme (and, for the web schemes, a host) is
    /// required before anything is treated as clickable.
    var openableURL: URL? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              Self.openableSchemes.contains(scheme) else {
            return nil
        }

        switch scheme {
        case "http", "https":
            guard let host = url.host(), !host.isEmpty else { return nil }
        default:
            // mailto:/tel: have no host — just require something after the scheme.
            guard trimmed.count > scheme.count + 1 else { return nil }
        }
        return url
    }
}

/// What a scan attempt produced. Drives which state the results popover shows.
enum ScanOutcome {
    case results([ScanResult])
    case empty
    case permissionRequired
    case failed(String)
}
