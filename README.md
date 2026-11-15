# Echo

<img src="Assets/Echo.png" alt="Echo clipboard icon" width="128" />

A lightweight, native macOS clipboard history app. Find a previous clip, press Return, and paste it into the app you were using.

## Features

- Keeps your latest 300 text and image clips, plus pinned clips, locally on your Mac.
- Search history and filter by text or images.
- Compact, resizable popup near the text caret, with a mouse-position fallback.
- Navigate clips with arrow keys and paste with Return or a click.
- Customizable global shortcut; defaults to **⌘⇧V**.
- Pin frequently used clips at the top, or remove individual clips.
- Edit a text clip in place or save a fragment as a new clip.
- Give text clips searchable aliases and optionally hide their contents.
- Native light and dark appearance, keyboard focus indicators, and accessible controls.
- Settings and history clearing from the popup or menu bar.

## Requirements

macOS 13 or later and Apple's Swift toolchain (Xcode or Command Line Tools).
There are no third-party package dependencies.

## Build and run

```sh
git clone https://github.com/bufferBrew/echo.git
cd echo
./build.sh
open /Applications/Echo.app
```

The script builds a release binary, assembles and signs `Echo.app`, and installs it in `/Applications`. To build without installing:

```sh
./build.sh --no-install
open Echo.app
```

## Usage

1. Launch Echo; it lives in the menu bar.
2. Copy text or an image in any app.
3. Place the caret in your destination and press **⌘⇧V**, or click Echo's menu bar icon.
4. Search, use **↑/↓** to select a clip, then press **Return** to paste. Clicking a clip also pastes it.
5. Press **Escape** to dismiss, **⌘F** to focus search, or **⌘,** to open settings.

Automatic paste requires **System Settings → Privacy & Security → Accessibility → Echo**. Without permission, selecting a clip still copies it to the clipboard so you can paste with **⌘V**. Ad-hoc builds can require granting permission again after rebuilding; see [stable local signing](SIGNING.md).

## Clip actions

Open the **…** menu beside a clip, or right-click it:

- **Pin to Top / Unpin** keeps a clip available beyond normal history cleanup.
- **Edit Clip…** changes a text clip in place; **Edit as New Clip…** creates a separate entry and preserves the original.
- **Remove from History** deletes a clip and its saved image, if any.

In the text editor, add an optional **alias** for commonly used text. Enable **Hide clip contents** and provide an alias to display only that alias in the popup. Hidden clips are searchable by alias rather than their contents and still paste their full text. The editor masks hidden text until you choose **Show text in editor**.

Hiding is a display feature: history is stored **unencrypted** on your Mac. Echo is not a password vault. **Clear History…** removes pinned clips too. Removing history does not erase text already on the system clipboard or in another app.

## Privacy and local storage

History and images are stored in `~/Library/Application Support/Echo`. History is persisted as JSON and images as PNG files, readable only by your user account (folders `0700`, files `0600`). The app has no network service or account; clips stay on your Mac. Clear saved clips using **Clear History…** in Echo's menu.

Echo does not record clipboard content that the source app marks as concealed, transient, or auto-generated ([nspasteboard.org](http://nspasteboard.org) markers). Password managers use these markers, so copied passwords are not saved. Apps that copy secrets without the markers are recorded like any other text.

If `history.json` cannot be read (for example, after disk corruption), Echo renames it to `history.unreadable-<timestamp>.json` and starts with an empty history, rather than overwriting it. Images are kept in that case so the history can be recovered by hand. On a normal launch, image files that no clip refers to are deleted.

Errors saving history, images, or the shortcut are logged under the `com.kartikjain.echo` subsystem. View them in Console.app, or run:

```sh
log stream --predicate 'subsystem == "com.kartikjain.echo"'
```

## Development

### Project layout

| Path | Contents |
|---|---|
| `Sources/Echo/HistoryStore.swift` | Clip history, pins, trimming, and JSON/PNG persistence |
| `Sources/Echo/ClipboardMonitor.swift` | Pasteboard polling and concealed-clip filtering |
| `Sources/Echo/HistoryViewModel.swift` | Search, filter, and keyboard selection state |
| `Sources/Echo/StatusBarController.swift` | Menu bar item, popup panel placement, and paste flow |
| `Sources/Echo/HotKey*.swift`, `ShortcutRecorder.swift` | Global shortcut registration and settings |
| `Sources/Echo/*View.swift` | SwiftUI popup, clip editor, and settings |
| `Tests/EchoTests/` | XCTest suite |

### Tests

```sh
swift test
```

The suite covers history recording, ordering, pin retention, the 300-clip limit, editing and hidden aliases, image files and cleanup, recovery from unreadable history, file permissions, search and selection, pasteboard monitoring (on a private pasteboard, so your real clipboard is untouched), password-manager filtering, shortcut persistence and refusal, and popup placement.

For a line-coverage report:

```sh
swift test --enable-code-coverage
xcrun llvm-cov report "$(swift build --show-bin-path)/EchoPackageTests.xctest/Contents/MacOS/EchoPackageTests" \
  -instr-profile "$(swift build --show-bin-path)/codecov/default.profdata" -ignore-filename-regex='(Tests|\.build)/'
```

These need a manual check on a real Mac: cross-app paste (with Accessibility permission, into an editable field), caret detection, the global shortcut, and the SwiftUI views.

### Continuous integration

`.github/workflows/ci.yml` runs on pull requests and pushes to `main`. Changes that touch only Markdown are skipped. On a `macos-15` runner it builds with warnings treated as errors, runs the tests with coverage (shown in the run summary), and assembles and verifies the ad-hoc-signed `Echo.app`. A Linux job runs `shellcheck` on `build.sh`. Standard GitHub-hosted runners are free for public repositories. Dependabot keeps the pinned actions current.

## Troubleshooting

- **Selecting a clip copies but doesn't paste.** Accessibility permission is missing or stale after a rebuild. See [stable local signing](SIGNING.md).
- **"Shortcut is unavailable" in Settings.** macOS or another app refused that key combination. Echo keeps your previous shortcut; choose another.
- **History disappeared after a crash.** Look for `history.unreadable-*.json` in `~/Library/Application Support/Echo`.

## Known limitations

- Only plain text and images are recorded. Rich text, files, and other pasteboard types are not.
- History is stored unencrypted. Hidden clips only hide text in the popup.
- The clipboard is polled every 0.5 seconds, so a clip replaced faster than that can be missed.
