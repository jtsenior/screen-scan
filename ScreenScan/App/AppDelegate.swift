import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var coordinator: ScanCoordinator?
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItemController = StatusItemController()
        let coordinator = ScanCoordinator(presenter: statusItemController)
        statusItemController.onScanRequested = { [weak coordinator] in
            coordinator?.beginScan()
        }

        self.statusItemController = statusItemController
        self.coordinator = coordinator

        do {
            hotKey = try HotKey { [weak coordinator] in
                coordinator?.beginScan()
            }
        } catch {
            // A failed registration almost always means something else already owns the
            // shortcut. The menu bar item still works, so keep running.
            NSLog("ScreenScan: could not register the global hot key: \(error)")
            statusItemController.reportHotKeyUnavailable()
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
