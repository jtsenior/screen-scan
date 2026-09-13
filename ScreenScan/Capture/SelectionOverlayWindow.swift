import AppKit

/// A transparent, borderless window covering exactly one display.
///
/// One window per `NSScreen` rather than a single window spanning every display: a spanning
/// window inherits one display's backing scale and gets the arrangement maths wrong the
/// moment the displays differ.
final class SelectionOverlayWindow: NSWindow {
    // An LSUIElement app has no key window by default, and without one the view never
    // receives `cancelOperation(_:)` — Esc would silently do nothing.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame,
                   styleMask: .borderless,
                   backing: .buffered,
                   defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Above the menu bar and the Dock, matching the native screenshot tool.
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        // Keep the overlay out of screenshots taken by *other* tools, and out of Exposé.
        sharingType = .none
        setFrame(screen.frame, display: false)
    }
}
