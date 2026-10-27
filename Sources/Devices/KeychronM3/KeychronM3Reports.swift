import Foundation

enum KeychronM3Reports {
    // Full 21-byte report, including its report ID. Never decode an empty,
    // stale, unrelated, or incorrectly routed response as a battery reading.
    static func decodeWired(_ bytes: [UInt8]) -> BatteryStatus? {
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
    static func decodeBluetooth(_ description: [String: Any]) -> BatteryStatus? {
        guard (description["Vendor ID"] as? NSNumber)?.intValue == 0x3434,
              (description["Product ID"] as? NSNumber)?.intValue == 0xD033,
              (description["Transport Type"] as? String)?.hasPrefix("Bluetooth") == true,
              description["Accessory Category"] as? String == "Mouse",
              let current = (description["Current Capacity"] as? NSNumber)?.doubleValue,
              let maximum = (description["Max Capacity"] as? NSNumber)?.doubleValue,
              current.isFinite, maximum.isFinite, maximum > 0, current >= 0, current <= maximum else { return nil }
        let charging = description["Is Charging"] as? Bool
        let onBattery = description["Power Source State"] as? String == "Battery Power"
        let state: UInt8? = charging == true ? 1 : onBattery ? 0 : nil
        return BatteryStatus(percentage: Int((100 * current / maximum).rounded()), powerState: state, usbRevision: nil)
    }
    static func hasNoTarget(_ report: [UInt8]) -> Bool {
        report.count == 21 && report[0] == 0x54 && report[1] == 0xE4 && report[2] == 2
            && report.dropFirst(3).allSatisfy { $0 == 0 }
    }
}
