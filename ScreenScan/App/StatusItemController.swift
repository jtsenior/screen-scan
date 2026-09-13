import AppKit
import SwiftUI

/// Owns the menu bar item and the popover the results are shown in.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var hotKeyAvailable = true

    var onScanRequested: (() -> Void)?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "qrcode.viewfinder",
                                accessibilityDescription: "ScreenScan")
            image?.isTemplate = true
            button.image = image
        }

        popover.behavior = .transient // click outside, or Esc, dismisses
        popover.animates = true

        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let scan = NSMenuItem(title: "Scan Region",
                              action: #selector(scanRegion),
                              keyEquivalent: "q")
        scan.keyEquivalentModifierMask = [.control, .option]
        scan.target = self
        menu.addItem(scan)

        if !hotKeyAvailable {
            let warning = NSMenuItem(title: "Shortcut \(HotKey.defaultDisplayString) unavailable",
                                     action: nil,
                                     keyEquivalent: "")
            warning.isEnabled = false
            menu.addItem(warning)
        }

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About ScreenScan",
                               action: #selector(showAbout),
                               keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit ScreenScan",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }

    /// Something else already owns ⌃⌥Q; surface it in the menu rather than failing silently.
    func reportHotKeyUnavailable() {
        hotKeyAvailable = false
        statusItem.menu = buildMenu()
    }

    /// Shows `view` in the popover anchored under the menu bar icon.
    func present(_ view: some View) {
        guard let button = statusItem.button else { return }

        popover.contentViewController = NSHostingController(rootView: view)
        // An accessory app isn't active after a global hot key fires, and a popover in an
        // inactive app takes no key events — so Esc wouldn't dismiss it.
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func dismiss() {
        popover.performClose(nil)
    }

    @objc private func scanRegion() {
        onScanRequested?()
    }

    @objc private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
