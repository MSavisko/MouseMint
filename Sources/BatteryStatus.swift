import Foundation

struct BatteryStatus: Equatable, Codable {
    let percentage: Int
    let powerState: UInt8
    let usbRevision: UInt16

    var powerDescription: String {
        switch powerState {
        case 0: return "On battery"
        case 1: return "Charging"
        case 2: return percentage == 100 ? "Fully charged" : "External power"
        default: return "Unknown power state (\(powerState))"
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
}

