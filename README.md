# ScreenScan

A small macOS menu bar app for reading QR codes that are on your screen. Press a shortcut, drag over the QR code (like taking a screenshot), and ScreenScan shows what the code says. You can open a link in your browser or copy the text.

## Features

- Lives in the menu bar and doesn't show a Dock icon
- Global shortcut **⌃⌥Q** (Control-Option-Q), or **Scan Region** from the menu bar icon
- Selecting a region works like the built-in screenshot tool: everything outside your selection is dimmed, and **Esc** cancels
- Works across multiple displays
- Reads every QR code in the selected region
- **Open in Browser** for `http`, `https`, `mailto` and `tel` links; everything else can only be copied
- If exactly one code is found, its text is copied to the clipboard automatically

## Requirements

- macOS 15 (Sequoia) or later
- Screen Recording permission
- To build: Xcode with Swift 6 (developed with Xcode 26)

## Usage

1. Launch ScreenScan. A QR code viewfinder icon appears in the menu bar.
2. Press **⌃⌥Q**, or click the icon and choose **Scan Region**.
3. Drag over the QR code. Press **Esc** to cancel.
4. The results appear in a popover under the menu bar icon.

If something else already uses ⌃⌥Q, the menu says the shortcut is unavailable. **Scan Region** in the menu still works.

## Screen Recording permission

macOS treats reading a region of the screen as screen recording, so ScreenScan asks for permission the first time you scan.

1. Click **Open System Settings** in the popover. You can also go to **System Settings → Privacy & Security → Screen & System Audio Recording** yourself.
2. Turn on **ScreenScan**.
3. Quit and reopen ScreenScan. macOS only applies the permission to a newly launched app.

ScreenScan only captures the region you select. It doesn't save the captured images, and it doesn't send anything over the network.

## Building from source

```sh
git clone <repository-url>
cd screen-scan
open ScreenScan.xcodeproj
```

Build and run the **ScreenScan** scheme.

### Signing and the Screen Recording permission

The project uses an ad-hoc signature by default. macOS ties the Screen Recording permission to the app's code signature, and an ad-hoc signature changes every time you build. With it, you may have to grant the permission again after each rebuild, or ScreenScan may not appear in the Screen Recording list at all.

To avoid that, sign with your own development certificate and build into a fixed folder:

```sh
xcodebuild -project ScreenScan.xcodeproj -scheme ScreenScan -configuration Debug \
  -derivedDataPath build/dd \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Apple Development: Your Name (XXXXXXXXXX)" \
  DEVELOPMENT_TEAM=YOURTEAMID \
  build

open build/dd/Build/Products/Debug/ScreenScan.app
```

`DEVELOPMENT_TEAM` is your team ID, which is not always the ID shown in parentheses in the certificate name. To find it, read the certificate's `OU` field:

```sh
security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
```

If ScreenScan still doesn't show up under Screen Recording, older builds may be registered with the same bundle ID. Unregister them, then reset the permission:

```sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u /path/to/old/ScreenScan.app
tccutil reset ScreenCapture com.joshuapyle.screenscan
```

## Running the tests

```sh
xcodebuild -project ScreenScan.xcodeproj -scheme ScreenScan test
```

The tests cover QR decoding against generated fixtures, deciding which payloads can be opened as links, and converting between screen coordinate systems.

## How it works

1. **Shortcut:** the ⌃⌥Q shortcut is registered with Carbon's `RegisterEventHotKey`. It needs no Accessibility permission, and the keystroke doesn't also reach the app in front.
2. **Selection:** each display gets its own borderless overlay window. The overlays are hidden from screen captures, including ScreenScan's own capture.
3. **Capture:** ScreenCaptureKit (`SCScreenshotManager`) captures just the selected rectangle at the display's full resolution. The selection is first converted from AppKit's bottom-left origin to Core Graphics' top-left origin.
4. **Decoding:** Vision's `DetectBarcodesRequest`, limited to QR codes, reads every code in the captured image.
5. **Results:** a SwiftUI view in an `NSPopover` shows each code's text, with **Copy** and, for supported links, **Open in Browser**.

### Project layout

```
ScreenScan/
  App/        App lifecycle, menu bar item, global shortcut, scan coordinator
  Capture/    Selection overlays, ScreenCaptureKit capture, coordinate conversion, permission check
  Scanning/   QR decoding with Vision
  Models/     Scan result and link detection
  UI/         Results and permission popovers
ScreenScanTests/
```

## License

MIT. See [LICENSE](LICENSE).

Made by [JT's Workshop](https://jts-workshop.com/).
