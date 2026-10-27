import Foundation

final class AutomaticNaturalScrolling {
    private let backend: NaturalScrollingBackend
    private let preferences: ScrollingPreferences
    var isAutomatic: Bool { preferences.automaticallySwitch }
    private(set) var state: NaturalScrollingState
    private(set) var failure: Error?

    init(backend: NaturalScrollingBackend, preferences: ScrollingPreferences) {
        self.backend = backend
        self.preferences = preferences
        state = backend.read()
    }

    func refreshStatus() { state = backend.read() }

    func setAutomatic(_ enabled: Bool) {
        preferences.automaticallySwitch = enabled
        failure = nil
        refreshStatus()
        // Enabling is applied after a fresh connection check by the app.
        // Disabling always leaves the system's current setting untouched.
    }

    func setManual(_ enabled: Bool) {
        guard !isAutomatic else { return }
        apply(enabled)
    }

    func update(connection: MouseConnectionState) {
        refreshStatus()
        guard let desired = ScrollingPolicy.desiredState(connection: connection, automatic: isAutomatic) else { return }
        apply(desired)
    }

    private func apply(_ desired: Bool) {
        do {
            if state.preference != desired || state.live != desired {
                try backend.setEnabled(desired)
                refreshStatus()
            }
            failure = nil
        } catch {
            refreshStatus()
            failure = error
        }
    }

}
