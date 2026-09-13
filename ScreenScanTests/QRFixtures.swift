import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Generates QR images in-process with CoreImage so the decoder tests need no checked-in
/// binary fixtures and no attached display.
enum QRFixtures {
    enum Failure: Error {
        case generationFailed
        case rasterizationFailed
    }

    /// A single QR code on a white background, with the quiet zone real scanners expect.
    static func image(payload: String, scale: CGFloat = 10, quietZone: CGFloat = 20) throws -> CGImage {
        let code = try rawCode(payload: payload, scale: scale)
        return try canvas(size: CGSize(width: CGFloat(code.width) + quietZone * 2,
                                       height: CGFloat(code.height) + quietZone * 2)) { context in
            context.draw(code, in: CGRect(x: quietZone,
                                          y: quietZone,
                                          width: CGFloat(code.width),
                                          height: CGFloat(code.height)))
        }
    }

    /// Two QR codes side by side, as a stand-in for a screenshot containing several.
    static func composite(payloads: [String], scale: CGFloat = 10, gap: CGFloat = 40) throws -> CGImage {
        let codes = try payloads.map { try rawCode(payload: $0, scale: scale) }
        let width = codes.reduce(gap) { $0 + CGFloat($1.width) + gap }
        let height = (codes.map { CGFloat($0.height) }.max() ?? 0) + gap * 2

        return try canvas(size: CGSize(width: width, height: height)) { context in
            var x = gap
            for code in codes {
                context.draw(code, in: CGRect(x: x,
                                              y: gap,
                                              width: CGFloat(code.width),
                                              height: CGFloat(code.height)))
                x += CGFloat(code.width) + gap
            }
        }
    }

    /// A blank white image — the "nothing to find here" case.
    static func blank(size: CGSize = CGSize(width: 200, height: 200)) throws -> CGImage {
        try canvas(size: size) { _ in }
    }

    private static func rawCode(payload: String, scale: CGFloat) throws -> CGImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let image = CIContext().createCGImage(output, from: output.extent) else {
            throw Failure.generationFailed
        }
        return image
    }

    private static func canvas(size: CGSize, draw: (CGContext) -> Void) throws -> CGImage {
        guard let context = CGContext(data: nil,
                                      width: Int(size.width),
                                      height: Int(size.height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw Failure.rasterizationFailed
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        draw(context)

        guard let image = context.makeImage() else { throw Failure.rasterizationFailed }
        return image
    }
}
