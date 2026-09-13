import AppKit

// Deliberately an AppKit bootstrap rather than a SwiftUI `MenuBarExtra`: the whole
// interaction model is "a global hot key presents the popover", and MenuBarExtra has no
// reliable way to be presented programmatically. SwiftUI is still used for the popover
// contents, hosted in an NSHostingController.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
