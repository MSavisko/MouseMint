import Foundation
import Darwin

struct NaturalScrollingOperations {
    var readPreference: () -> Bool?
    var readLive: (() -> Bool)?
    var savePreference: (Bool) -> Bool
    var applyLive: ((Bool) -> Void)?
    var close: () -> Void = {}
}
final class SystemNaturalScrolling: NaturalScrollingBackend {
    private let operations: NaturalScrollingOperations
    init(operations: NaturalScrollingOperations = SystemNaturalScrolling.nativeOperations()) { self.operations = operations }
    func read() -> NaturalScrollingState {
        NaturalScrollingState(preference: operations.readPreference(), live: operations.readLive?())
    }
    func setEnabled(_ enabled: Bool) throws {
        guard operations.readLive != nil, let apply = operations.applyLive else { throw NaturalScrollingError.unavailable }
        guard operations.savePreference(enabled) else { throw NaturalScrollingError.saveFailed }
        apply(enabled)
        let state = read()
        guard state.preference == enabled, state.live == enabled else { throw NaturalScrollingError.applyFailed }
    }
    deinit { operations.close() }

    static func nativeOperations() -> NaturalScrollingOperations {
        typealias Getter = @convention(c) () -> Bool
        typealias Setter = @convention(c) (Bool) -> Void
        let key = "com.apple.swipescrolldirection" as CFString
        let library = dlopen("/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/PreferencePanesSupport", RTLD_NOW)
        let getter: Getter? = library.flatMap { dlsym($0, "swipeScrollDirection") }.map { unsafeBitCast($0, to: Getter.self) }
        let setter: Setter? = library.flatMap { dlsym($0, "setSwipeScrollDirection") }.map { unsafeBitCast($0, to: Setter.self) }
        return NaturalScrollingOperations(readPreference: {
            CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            return CFPreferencesCopyValue(key, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? Bool
        }, readLive: getter.map { get in { get() } }, savePreference: { value in
            CFPreferencesSetValue(key, value ? kCFBooleanTrue : kCFBooleanFalse,
                kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            return CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }, applyLive: setter.map { set in { value in set(value) } }, close: { if let library { dlclose(library) } })
    }
}
