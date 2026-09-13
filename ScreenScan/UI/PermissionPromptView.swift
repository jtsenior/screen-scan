import AppKit
import SwiftUI

struct PermissionPromptView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Screen Recording permission needed", systemImage: "lock.shield")
                .font(.headline)

            Text("""
                 ScreenScan reads the region you select, which macOS treats as recording the \
                 screen. Turn on ScreenScan under Privacy & Security → Screen Recording, then \
                 relaunch the app — macOS only applies a new grant to a freshly launched process.
                 """)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("Open System Settings") {
                    ScreenRecordingPermission.openSystemSettings()
                }
                .buttonStyle(.borderedProminent)

                Button("Quit ScreenScan") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}
