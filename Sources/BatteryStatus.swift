import Foundation

struct BatteryStatus: Equatable, Codable {
    let percentage: Int
    let powerState: UInt8?
    let usbRevision: UInt16?

    var powerDescription: String {
        switch powerState {
        case 0: return "On battery"
        case 1: return "Charging"
        case 2: return percentage == 100 ? "Fully charged" : "External power"
        case nil: return "Not reported by macOS"
        default: return "Unknown power state (\(powerState!))"
        }
    }

    // Full 21-byte report, including its report ID. Never decode an empty,
    // stale, unrelated, or incorrectly routed response as a battery reading.
    static func decode(_ bytes: [UInt8]) -> BatteryStatus? {
        guard bytes.count >= 21, bytes[0] == 0x51, bytes[1] == 0x06,
              bytes[2] == 1, bytes[4...7].elementsEqual([0x34, 0x34, 0x33, 0xD0]),
              bytes[11] <= 100 else { return nil }
        return BatteryStatus(percentage: Int(bytes[11]), powerState: bytes[12],
                             usbRevision: UInt16(bytes[8]) | UInt16(bytes[9]) << 8)
    }

    static func decodeReceiver(_ bytes: [UInt8]) -> BatteryStatus? {
        // Captured D031 notification reply to 51 0C 02. A complete reply
        // contains a result, link state, power state, level and firmware text.
        guard bytes.count == 21, bytes[0] == 0x54, bytes[1] == 0xE3,
              bytes[2] == 0, bytes[3] == 3, bytes[4] <= 2, bytes[5] <= 100,
              bytes[7] >= 2, Int(bytes[7]) <= bytes.count - 8,
              bytes[7 + Int(bytes[7])] == 0,
              bytes[8..<(7 + Int(bytes[7]))].allSatisfy({ $0 >= 0x20 && $0 <= 0x7E }) else { return nil }
        return BatteryStatus(percentage: Int(bytes[5]), powerState: bytes[4], usbRevision: nil)
    }
}

