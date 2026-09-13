import AppKit

/// Drives the pipeline: permission → region selection → capture → decode → present.
@MainActor
final class ScanCoordinator {
    private let presenter: StatusItemController
    private let overlay = SelectionOverlayController()
    private var isScanning = false

    init(presenter: StatusItemController) {
        self.presenter = presenter
    }

    func beginScan() {
        guard !isScanning else { return }

        // Check before showing the overlay — there's no point letting someone drag out a
        // region that can't be captured.
        guard ScreenRecordingPermission.isGranted else {
            ScreenRecordingPermission.request() // surfaces the system prompt, the first time only
            presenter.present(PermissionPromptView())
            return
        }

        isScanning = true
        presenter.dismiss()

        overlay.begin { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .cancelled:
                overlay.dismiss()
                isScanning = false
            case .selected(let selection):
                Task { await self.captureAndDecode(selection) }
            }
        }
    }

    private func captureAndDecode(_ selection: SelectionOverlayController.Selection) async {
        defer {
            overlay.dismiss()
            isScanning = false
        }

        do {
            let image = try await ScreenCapturer.capture(globalRect: selection.globalRect,
                                                         on: selection.screen,
                                                         excludingWindowNumbers: selection.overlayWindowNumbers)
            // The capture is done, so the scrim can come down before the (much faster) decode.
            overlay.dismiss()

            let results = try await QRDecoder.decode(image)
            present(results.isEmpty ? .empty : .results(results))
        } catch ScreenCapturer.Failure.permissionDenied {
            present(.permissionRequired)
        } catch {
            present(.failed(error.localizedDescription))
        }
    }

    private func present(_ outcome: ScanOutcome) {
        if case .permissionRequired = outcome {
            presenter.present(PermissionPromptView())
            return
        }

        // One result is unambiguous, so copy it without being asked. Multiple results stay
        // explicit — guessing which one was wanted would be worse than not copying.
        var autoCopied = false
        if case .results(let results) = outcome, let only = results.first, results.count == 1 {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(only.payload, forType: .string)
            autoCopied = true
        }

        presenter.present(ResultsView(outcome: outcome, autoCopied: autoCopied) { [weak self] in
            self?.beginScan()
        })
    }
}
