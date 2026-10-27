import Foundation

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

enum NaturalScrollingError: Error, Equatable {
    case unavailable, saveFailed, applyFailed
}
