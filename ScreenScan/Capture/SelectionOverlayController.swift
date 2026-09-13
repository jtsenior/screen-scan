import AppKit

/// Puts a selection overlay on every display and reports back what the user dragged.
@MainActor
final class SelectionOverlayController: NSObject, SelectionViewDelegate {
    struct Selection {
        /// The selected region in AppKit's global space (origin bottom-left of the primary display).
        let globalRect: CGRect
        /// The display the drag happened on.
        let screen: NSScreen
        /// Window numbers of the overlays, so the capture can exclude them.
        let overlayWindowNumbers: [Int]
    }

    enum Outcome {
        case selected(Selection)
        case cancelled
    }

    private var windows: [SelectionOverlayWindow] = []
    private var completion: ((Outcome) -> Void)?
    private var keyMonitor: Any?

    var isActive: Bool { !windows.isEmpty }

    /// Shows the overlays. The windows deliberately stay on screen after `completion` runs
    /// so the capture can exclude them by window number — call `dismiss()` once the capture
    /// is finished.
    func begin(completion: @escaping (Outcome) -> Void) {
        guard windows.isEmpty else { return }
        self.completion = completion

        for screen in NSScreen.screens {
            let window = SelectionOverlayWindow(screen: screen)
            let view = SelectionView(frame: window.contentLayoutRect)
            view.autoresizingMask = [.width, .height]
            view.delegate = self
            window.contentView = view
            window.orderFrontRegardless()
            windows.append(window)
        }

        NSApp.activate()
        windows.first?.makeKeyAndOrderFront(nil)
        windows.first?.makeFirstResponder(windows.first?.contentView)

        // Belt and braces for Esc: `cancelOperation(_:)` needs the overlay to be first
        // responder, which is not guaranteed for an accessory app that was never activated.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53 /* Esc */ else { return event }
            MainActor.assumeIsolated { self.finish(.cancelled) }
            return nil
        }
    }

    /// Tears the overlays down. Safe to call more than once.
    func dismiss() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }

    private func finish(_ outcome: Outcome) {
        guard let completion else { return }
        self.completion = nil
        completion(outcome)
    }

    // MARK: - SelectionViewDelegate

    func selectionViewDidBeginSelecting(_ view: SelectionView) {
        // Only the display the drag started on shows a selection; the rest stay dimmed.
        for window in windows where window.contentView !== view {
            (window.contentView as? SelectionView)?.clearSelection()
        }
    }

    func selectionView(_ view: SelectionView, didCompleteSelection rect: CGRect) {
        guard let window = view.window, let screen = window.screen else {
            finish(.cancelled)
            return
        }

        let globalRect = window.convertToScreen(view.convert(rect, to: nil))
        finish(.selected(Selection(globalRect: globalRect,
                                   screen: screen,
                                   overlayWindowNumbers: windows.map(\.windowNumber))))
    }

    func selectionViewDidCancel(_ view: SelectionView) {
        finish(.cancelled)
    }
}
