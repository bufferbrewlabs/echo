import AppKit

final class ShortcutRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var keyCode: UInt32 = HotKeyPreference.keyCode
    @Published var modifiers: UInt32 = HotKeyPreference.modifiers
    @Published var errorMessage: String?

    /// Applies a new shortcut; returns false when the system refuses it.
    var onChange: ((UInt32, UInt32) -> Bool)?

    private var monitor: Any?

    var displayString: String {
        HotKeyPreference.displayString(keyCode: keyCode, modifiers: modifiers)
    }

    func startRecording() {
        errorMessage = nil
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, event.type == .keyDown else { return event }
            self.handle(event)
            return nil // swallow the event while recording
        }
    }

    func cancelRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53 {
            errorMessage = nil
            cancelRecording()
            return
        }
        let carbonModifiers = HotKeyPreference.carbonModifiers(from: event.modifierFlags)
        guard carbonModifiers != 0 else {
            errorMessage = "Shortcut must include at least one modifier key (⌘ ⇧ ⌥ ⌃)."
            return
        }
        cancelRecording()
        apply(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers)
    }

    /// Saves and activates a shortcut only if the system accepts it, so a refused
    /// combination never replaces a working one.
    func apply(keyCode newKeyCode: UInt32, modifiers newModifiers: UInt32) {
        if let onChange, !onChange(newKeyCode, newModifiers) {
            errorMessage = "\(HotKeyPreference.displayString(keyCode: newKeyCode, modifiers: newModifiers)) is unavailable. Try another shortcut."
            return
        }
        errorMessage = nil
        keyCode = newKeyCode
        modifiers = newModifiers
        HotKeyPreference.set(keyCode: newKeyCode, modifiers: newModifiers)
    }

    func resetToDefault() {
        cancelRecording()
        apply(keyCode: HotKeyPreference.defaultKeyCode, modifiers: HotKeyPreference.defaultModifiers)
    }
}
