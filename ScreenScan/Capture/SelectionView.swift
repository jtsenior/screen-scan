import AppKit

@MainActor
protocol SelectionViewDelegate: AnyObject {
    /// A drag started in this view, so every other overlay should stop showing a selection.
    func selectionViewDidBeginSelecting(_ view: SelectionView)
    func selectionView(_ view: SelectionView, didCompleteSelection rect: CGRect)
    func selectionViewDidCancel(_ view: SelectionView)
}

/// Draws the dimming scrim and the selection rectangle, and owns the drag.
final class SelectionView: NSView {
    weak var delegate: (any SelectionViewDelegate)?

    private var anchor: CGPoint?
    private var selection: CGRect? {
        didSet { needsDisplay = true }
    }

    // Bottom-left origin, matching the window and screen coordinate spaces so the rect can
    // be handed straight to `convertToScreen` without another flip.
    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    func clearSelection() {
        anchor = nil
        selection = nil
    }

    // MARK: - Drawing

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        context.fill(bounds)

        guard let selection, !selection.isEmpty else { return }

        // Punch the selection out of the scrim so what's underneath is at full brightness —
        // far easier to read than a plain outline, and it matches the native tool.
        context.setBlendMode(.destinationOut)
        context.setFillColor(NSColor.black.cgColor)
        context.fill(selection)
        context.setBlendMode(.normal)

        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1)
        context.stroke(selection.insetBy(dx: 0.5, dy: 0.5))

        drawSizeBadge(for: selection)
    }

    private func drawSizeBadge(for rect: CGRect) {
        let text = "\(Int(rect.width)) × \(Int(rect.height))" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let textSize = text.size(withAttributes: attributes)
        let padding = CGSize(width: 6, height: 3)

        var badge = CGRect(x: rect.midX - (textSize.width + padding.width * 2) / 2,
                           y: rect.minY - textSize.height - padding.height * 2 - 4,
                           width: textSize.width + padding.width * 2,
                           height: textSize.height + padding.height * 2)
        // Flip the badge inside the selection when the drag reaches the bottom of the screen.
        if badge.minY < bounds.minY + 4 {
            badge.origin.y = rect.minY + 4
        }
        badge.origin.x = min(max(badge.origin.x, bounds.minX + 4), bounds.maxX - badge.width - 4)

        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 4, yRadius: 4).fill()
        text.draw(at: CGPoint(x: badge.minX + padding.width, y: badge.minY + padding.height),
                  withAttributes: attributes)
    }

    // MARK: - Dragging

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        anchor = point
        selection = CGRect(origin: point, size: .zero)
        delegate?.selectionViewDidBeginSelecting(self)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let anchor else { return }
        selection = ScreenGeometry.rect(from: anchor, to: convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        guard let anchor else { return }
        let rect = ScreenGeometry.rect(from: anchor, to: convert(event.locationInWindow, from: nil))
        self.anchor = nil

        // A stray click shouldn't try to capture a 1x1 region.
        if ScreenGeometry.isUsable(rect) {
            delegate?.selectionView(self, didCompleteSelection: rect)
        } else {
            delegate?.selectionViewDidCancel(self)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        delegate?.selectionViewDidCancel(self)
    }

    /// Esc, routed through the responder chain.
    override func cancelOperation(_ sender: Any?) {
        delegate?.selectionViewDidCancel(self)
    }
}
