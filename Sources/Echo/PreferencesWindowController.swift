import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    convenience init(recorder: ShortcutRecorder, launchAtLogin: LaunchAtLogin) {
        let hosting = NSHostingController(rootView: PreferencesView(recorder: recorder, launchAtLogin: launchAtLogin))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Echo Settings"
        window.styleMask = [.titled, .closable, .resizable]
        window.contentMinSize = NSSize(width: 420, height: 500)
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
