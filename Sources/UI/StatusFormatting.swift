import Foundation

extension BatteryStatus {
    var powerDescription: String {
        switch powerState {
        case 0: return "On battery"
        case 1: return "Charging"
        case 2: return percentage == 100 ? "Fully charged" : "External power"
        case nil: return "Not reported by macOS"
        default: return "Unknown power state (\(powerState!))"
        }
    }

}
extension ConnectionMode {
    var title: String {
        switch self {
        case .cable: return "USB cable"
        case .receiver: return "2.4 GHz receiver"
        case .bluetooth: return "Bluetooth"
        }
    }

}
extension MouseReadError: CustomStringConvertible {
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
    private static func hex(_ value: Int32) -> String { String(format: "0x%08x", value) }
}
