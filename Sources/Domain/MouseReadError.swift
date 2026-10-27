import Foundation

enum MouseReadError: Error, Equatable {
    case disconnected, receiverDisconnected, receiverUnavailable, access(Int32), request(Int32), response(Int32), invalid

    func scrollingConnection(directMousePresent: Bool) -> MouseConnectionState {
        if directMousePresent { return .connected }
        switch self {
        case .disconnected, .receiverDisconnected: return .disconnected
        default: return .unknown
        }
    }

}
