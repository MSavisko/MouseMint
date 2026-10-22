import Foundation

@main struct BatteryTests {
    static func main() {
        let captured: [UInt8] = [0x51, 0x06, 1, 0, 0x34, 0x34, 0x33, 0xD0, 0x23, 1, 0, 100, 2, 0, 0, 0, 0, 0, 0, 0, 0]
        let full = BatteryStatus.decode(captured)!
        precondition(full.percentage == 100 && full.powerState == 2 && full.usbRevision == 0x0123)
        precondition(BatteryStatus.decode(Array(captured.prefix(12))) == nil)
        precondition(BatteryStatus.decode([UInt8](repeating: 0, count: 21)) == nil)
        for index in [0, 1, 2, 4, 5, 6, 7] {
            var bad = captured; bad[index] ^= 1
            precondition(BatteryStatus.decode(bad) == nil)
        }
        var bad = captured; bad[11] = 101
        precondition(BatteryStatus.decode(bad) == nil)
        var empty = captured; empty[11] = 0; empty[12] = 0
        precondition(BatteryStatus.decode(empty)?.percentage == 0)
        precondition(full.powerDescription == "Fully charged")
        precondition(BatteryStatus(percentage: 55, powerState: 1, usbRevision: 0x0123).powerDescription == "Charging")
        precondition(BatteryStatus(percentage: 55, powerState: 2, usbRevision: 0x0123).powerDescription == "External power")
        precondition(BatteryStatus(percentage: 55, powerState: 9, usbRevision: 0x0123).powerDescription == "Unknown power state (9)")
        print("Battery report decoding and power-state checks passed.")
    }
}
