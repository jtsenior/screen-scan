import AppKit
import SwiftUI

struct ResultsView: View {
    let outcome: ScanOutcome
    /// Set when a lone result was copied to the clipboard automatically.
    let autoCopied: Bool
    let onRescan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch outcome {
            case .results(let results):
                resultsContent(results)
            case .empty:
                message(title: "No QR code found",
                        detail: "Nothing in the selected region decoded as a QR code. Try selecting a larger area.",
                        symbol: "viewfinder.slash")
            case .failed(let description):
                message(title: "Couldn’t capture the screen", detail: description, symbol: "exclamationmark.triangle")
            case .permissionRequired:
                // Handled by PermissionPromptView; here only for exhaustiveness.
                message(title: "Screen Recording permission needed",
                        detail: "Enable ScreenScan under Privacy & Security → Screen Recording.",
                        symbol: "lock.shield")
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    @ViewBuilder
    private func resultsContent(_ results: [ScanResult]) -> some View {
        HStack {
            Text(results.count == 1 ? "1 QR code" : "\(results.count) QR codes")
                .font(.headline)
            Spacer()
            if autoCopied {
                Label("Copied", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        // Anything past a handful scrolls rather than growing the popover off-screen.
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    if index > 0 { Divider() }
                    ResultRow(result: result)
                }
            }
        }
        .frame(maxHeight: results.count > 3 ? 260 : .infinity)
        .fixedSize(horizontal: false, vertical: results.count <= 3)
    }

    @ViewBuilder
    private func message(title: String, detail: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.headline)
        Text(detail)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        Button("Scan Again", action: onRescan)
    }
}

private struct ResultRow: View {
    let result: ScanResult
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Always show the raw payload — for a link this is what makes the destination
            // visible before it is opened.
            Text(result.payload)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(5)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if let url = result.openableURL {
                    Button("Open in Browser") {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button(didCopy ? "Copied" : "Copy", action: copy)
                    .disabled(didCopy)
            }
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.payload, forType: .string)
        didCopy = true
    }
}
