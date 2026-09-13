import CoreGraphics
import Vision

enum QRDecoder {
    /// Decodes every QR code in the image. An image with no codes is not an error.
    static func decode(_ image: CGImage) async throws -> [ScanResult] {
        var request = DetectBarcodesRequest()
        request.symbologies = [.qr]

        let observations = try await request.perform(on: image)
        return observations.compactMap { observation in
            guard let payload = observation.payloadString, !payload.isEmpty else { return nil }
            return ScanResult(payload: payload, boundingBox: observation.boundingBox.cgRect)
        }
    }
}
