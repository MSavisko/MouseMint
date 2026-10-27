import Foundation

enum MouseReadError: Error, CustomStringConvertible, Equatable {
    case disconnected, receiverDisconnected, receiverUnavailable, access(Int32), request(Int32), response(Int32), invalid

    var description: String {
        switch self {
        case .disconnected: return "Connect your M3 by cable, receiver, or Bluetooth."
        case .receiverDisconnected: return "The receiver reports that the mouse is not connected."
        case .receiverUnavailable: return "The receiver did not reply. Checking the mouse connection again."
        case .access(let code): return "USB access denied or busy (\(Self.hex(code))). Close Keychron Engine and reopen this app."
        case .request(let code): return "Status request failed (\(Self.hex(code))). Reconnect the mouse."
        case .response(let code): return "Status read failed (\(Self.hex(code))). Reconnect the mouse."
        case .invalid: return "The mouse returned an unrecognized status. Battery level is unavailable."
        }
    }
    func scrollingConnection(directMousePresent: Bool) -> MouseConnectionState {
        if directMousePresent { return .connected }
        switch self {
        case .disconnected, .receiverDisconnected: return .disconnected
        default: return .unknown
        }
    }
    private static func hex(_ value: Int32) -> String { String(format: "0x%08x", value) }
}

struct MouseReading: Codable {
    enum CodingKeys: String, CodingKey { case date, status, rawReport, mode, productID }
    var deviceName: String? = nil
    let date: Date
    let status: BatteryStatus?
    let rawReport: [UInt8]
    let mode: ConnectionMode
    let productID: Int
}
