import Foundation
import ServiceManagement

/// Registers Echo as a login item through SMAppService (macOS 13+).
final class LaunchAtLogin: ObservableObject {
    private static let didSetDefaultKey = "LaunchAtLoginDefaultApplied"

    @Published private(set) var isEnabled = SMAppService.mainApp.status == .enabled
    @Published private(set) var errorMessage: String?

    /// Turns launch at login on once, the first time Echo runs. After that the
    /// user's choice in Settings (or System Settings > Login Items) wins.
    func applyDefaultIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.didSetDefaultKey) else { return }
        defaults.set(true, forKey: Self.didSetDefaultKey)
        setEnabled(true)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
