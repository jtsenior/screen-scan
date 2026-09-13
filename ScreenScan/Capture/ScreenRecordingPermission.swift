import AppKit
import CoreGraphics

enum ScreenRecordingPermission {
    /// Checks the current grant without prompting.
    static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Surfaces the system prompt. macOS only shows it once per app; afterwards this is a
    /// no-op and System Settings is the only way to change the answer. A newly granted
    /// permission does not apply to the running process — the app has to be relaunched.
    @discardableResult
    static func request() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
