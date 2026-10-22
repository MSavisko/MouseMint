import Foundation
import Darwin

enum MouseConnectionState {
    case connected, disconnected, unknown
}

struct NaturalScrollingState: Codable, Equatable {
    let preference: Bool?
    let live: Bool?
}

protocol NaturalScrollingBackend {
    func read() -> NaturalScrollingState
    func setEnabled(_ enabled: Bool) throws
}

protocol ScrollingPreferences: AnyObject {
    var automaticallySwitch: Bool { get set }
}

final class SavedScrollingPreferences: ScrollingPreferences {
    private let defaults: UserDefaults
    private let key = "automaticallySwitchNaturalScrolling"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var automaticallySwitch: Bool {
        get { defaults.object(forKey: key) as? Bool ?? true }
        set { defaults.set(newValue, forKey: key) }
    }
}

enum NaturalScrollingError: Error, CustomStringConvertible {
    case unavailable, saveFailed, applyFailed

    var description: String {
        switch self {
        case .unavailable: return "This macOS version cannot apply Natural Scrolling automatically."
        case .saveFailed: return "Could not save the Natural Scrolling setting."
        case .applyFailed: return "macOS did not confirm the Natural Scrolling change."
        }
    }
}

final class SystemNaturalScrolling: NaturalScrollingBackend {
    private typealias Getter = @convention(c) () -> Bool
    private typealias Setter = @convention(c) (Bool) -> Void
    private let library: UnsafeMutableRawPointer?
    private let getter: Getter?
    private let setter: Setter?
    private let key = "com.apple.swipescrolldirection" as CFString

    init() {
        library = dlopen("/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/PreferencePanesSupport", RTLD_NOW)
        if let library, let get = dlsym(library, "swipeScrollDirection"), let set = dlsym(library, "setSwipeScrollDirection") {
            getter = unsafeBitCast(get, to: Getter.self)
            setter = unsafeBitCast(set, to: Setter.self)
        } else {
            getter = nil
            setter = nil
        }
    }

    deinit { if let library { dlclose(library) } }

    func read() -> NaturalScrollingState {
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let preference = CFPreferencesCopyValue(key, kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? Bool
        return NaturalScrollingState(preference: preference, live: getter?())
    }

    func setEnabled(_ enabled: Bool) throws {
        // Updating the preference alone does not apply the live scroll direction.
        // Load both native functions before writing anything; fail explicitly if
        // Apple removes them instead of claiming a preference-only change works.
        guard getter != nil, let setter else { throw NaturalScrollingError.unavailable }
        CFPreferencesSetValue(key, enabled ? kCFBooleanTrue : kCFBooleanFalse,
            kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        else { throw NaturalScrollingError.saveFailed }
        setter(enabled)
        let state = read()
        guard state.preference == enabled, state.live == enabled else { throw NaturalScrollingError.applyFailed }
    }
}

final class AutomaticNaturalScrolling {
    private let backend: NaturalScrollingBackend
    private let preferences: ScrollingPreferences
    var isAutomatic: Bool { preferences.automaticallySwitch }
    private(set) var state: NaturalScrollingState
    private(set) var errorMessage: String?

    init(backend: NaturalScrollingBackend = SystemNaturalScrolling(), preferences: ScrollingPreferences = SavedScrollingPreferences()) {
        self.backend = backend
        self.preferences = preferences
        state = backend.read()
    }

    func refreshStatus() { state = backend.read() }

    func setAutomatic(_ enabled: Bool) {
        preferences.automaticallySwitch = enabled
        errorMessage = nil
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
        guard isAutomatic else { return }
        let desired: Bool
        switch connection {
        case .connected: desired = false
        case .disconnected: desired = true
        case .unknown: return // A read failure does not establish disconnection.
        }
        apply(desired)
    }

    private func apply(_ desired: Bool) {
        do {
            if state.preference != desired || state.live != desired {
                try backend.setEnabled(desired)
                refreshStatus()
            }
            errorMessage = nil
        } catch {
            refreshStatus()
            errorMessage = String(describing: error)
        }
    }

    var menuTitle: String {
        if errorMessage != nil { return "Natural Scrolling: Could not update" }
        guard let enabled = state.live else { return "Natural Scrolling: Unavailable" }
        return "Natural Scrolling: \(enabled ? "On" : "Off") (\(isAutomatic ? "automatic" : "manual"))"
    }
}
