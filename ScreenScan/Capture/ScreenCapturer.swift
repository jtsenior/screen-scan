import AppKit
import CoreGraphics
import ScreenCaptureKit

// The whole pipeline stays on the main actor: capture and decode are both fast enough that
// backgrounding buys nothing, and it avoids `Sendable` friction around NSScreen and CGImage.
@MainActor
enum ScreenCapturer {
    enum Failure: LocalizedError {
        case permissionDenied
        case displayNotFound
        case captureFailed(any Error)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "ScreenScan does not have permission to record the screen."
            case .displayNotFound:
                "The display holding the selection is no longer available."
            case .captureFailed(let error):
                error.localizedDescription
            }
        }
    }

    /// Captures a region selected in AppKit's global coordinate space.
    ///
    /// - Parameter excludingWindowNumbers: the selection overlays. They are still on screen
    ///   at this point, so without excluding them the capture comes back dimmed by the
    ///   scrim — dark enough that Vision can fail to decode. Ordering them out first and
    ///   hoping the compositor caught up is the timing-sensitive alternative.
    static func capture(globalRect: CGRect,
                        on screen: NSScreen,
                        excludingWindowNumbers: [Int]) async throws -> CGImage {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false,
                                                                          onScreenWindowsOnly: true)
        } catch {
            // Permission can also be revoked while the app is running, not just at launch.
            throw ScreenRecordingPermission.isGranted ? Failure.captureFailed(error) : Failure.permissionDenied
        }

        guard let displayID = screen.displayID,
              let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw Failure.displayNotFound
        }

        let overlays = content.windows.filter { excludingWindowNumbers.contains(Int($0.windowID)) }
        let filter = SCContentFilter(display: display, excludingWindows: overlays)

        // Specifically the *primary* display's height — the one whose AppKit frame origin is
        // (0, 0) — which need not be the display the drag happened on.
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        let coreGraphicsRect = ScreenGeometry.convertToCoreGraphics(rect: globalRect,
                                                                   primaryScreenHeight: primaryHeight)
        let sourceRect = ScreenGeometry.sourceRect(forGlobalRect: coreGraphicsRect,
                                                  displayBounds: CGDisplayBounds(displayID))
        let pixelSize = ScreenGeometry.pixelSize(for: sourceRect.size,
                                                 scaleFactor: screen.backingScaleFactor)

        let configuration = SCStreamConfiguration()
        configuration.sourceRect = sourceRect
        configuration.width = pixelSize.width
        configuration.height = pixelSize.height
        configuration.captureResolution = .best
        configuration.scalesToFit = false
        configuration.showsCursor = false
        configuration.ignoreShadowsDisplay = true

        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter,
                                                              configuration: configuration)
        } catch {
            throw Failure.captureFailed(error)
        }
    }
}

extension NSScreen {
    /// The `CGDirectDisplayID` backing this screen, used to match it to an `SCDisplay`.
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
