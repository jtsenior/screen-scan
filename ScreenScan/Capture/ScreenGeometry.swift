import CoreGraphics

/// Coordinate math for turning a drag into something ScreenCaptureKit understands.
///
/// AppKit's global space has its origin at the **bottom-left** of the primary display with
/// y growing up; Core Graphics and ScreenCaptureKit put the origin at the **top-left** with
/// y growing down. Getting this wrong produces a capture that is vertically offset — and on
/// a single-display setup the error is easy to miss, so these are kept as pure functions
/// that can be unit-tested without any display attached.
enum ScreenGeometry {
    /// Drags shorter than this in either dimension are treated as a stray click.
    static let minimumDragLength: CGFloat = 5

    /// Normalizes two drag endpoints into a rect, snapped to whole points.
    static func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(x: min(start.x, end.x),
               y: min(start.y, end.y),
               width: abs(end.x - start.x),
               height: abs(end.y - start.y)).integral
    }

    static func isUsable(_ rect: CGRect) -> Bool {
        rect.width >= minimumDragLength && rect.height >= minimumDragLength
    }

    /// AppKit global space → Core Graphics global space.
    ///
    /// - Parameter primaryScreenHeight: `NSScreen.screens[0].frame.maxY`. It must be the
    ///   *primary* display — the one whose AppKit frame origin is `(0, 0)` — which is not
    ///   necessarily the display the drag happened on.
    static func convertToCoreGraphics(rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.origin.x,
               y: primaryScreenHeight - rect.maxY,
               width: rect.width,
               height: rect.height)
    }

    /// Core Graphics global space → a rect relative to one display's own top-left corner,
    /// which is the space `SCStreamConfiguration.sourceRect` is expressed in.
    static func sourceRect(forGlobalRect rect: CGRect, displayBounds: CGRect) -> CGRect {
        rect.offsetBy(dx: -displayBounds.origin.x, dy: -displayBounds.origin.y)
    }

    /// Pixel dimensions for a point-sized region on a display with the given scale factor.
    ///
    /// Capturing at point dimensions on a 2x display halves the resolution, which
    /// measurably hurts decode rates on small QR codes.
    static func pixelSize(for size: CGSize, scaleFactor: CGFloat) -> (width: Int, height: Int) {
        (max(1, Int((size.width * scaleFactor).rounded())),
         max(1, Int((size.height * scaleFactor).rounded())))
    }
}
