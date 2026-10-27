import XCTest
import Foundation

final class BatteryTests: XCTestCase {
    func testBehavior() {
        let captured: [UInt8] = [0x51, 0x06, 1, 0, 0x34, 0x34, 0x33, 0xD0, 0x23, 1, 0, 100, 2, 0, 0, 0, 0, 0, 0, 0, 0]
        let full = KeychronM3Reports.decodeWired(captured)!
        XCTAssertTrue(full.percentage == 100 && full.powerState == 2 && full.usbRevision == 0x0123)
        XCTAssertTrue(KeychronM3Reports.decodeWired(Array(captured.prefix(12))) == nil)
        XCTAssertTrue(KeychronM3Reports.decodeWired([UInt8](repeating: 0, count: 21)) == nil)
        for index in [0, 1, 2, 4, 5, 6, 7] {
            var bad = captured; bad[index] ^= 1
            XCTAssertTrue(KeychronM3Reports.decodeWired(bad) == nil)
        }
        var bad = captured; bad[11] = 101
        XCTAssertTrue(KeychronM3Reports.decodeWired(bad) == nil)
        var empty = captured; empty[11] = 0; empty[12] = 0
        XCTAssertTrue(KeychronM3Reports.decodeWired(empty)?.percentage == 0)
        XCTAssertTrue(full.powerDescription == "Fully charged")
        XCTAssertTrue(BatteryStatus(percentage: 55, powerState: 1, usbRevision: 0x0123).powerDescription == "Charging")
        XCTAssertTrue(BatteryStatus(percentage: 55, powerState: 2, usbRevision: 0x0123).powerDescription == "External power")
        XCTAssertTrue(BatteryStatus(percentage: 55, powerState: 9, usbRevision: 0x0123).powerDescription == "Unknown power state (9)")
        let receiver: [UInt8] = [0x54, 0xE3, 0, 3, 0, 98, 0, 7, 0x31, 0x2E, 0x32, 0x2E, 0x33, 0x72, 0, 0, 0, 0, 0, 0, 0]
        // The captured length field includes its terminating NUL.
        let packet = receiver
        XCTAssertTrue(KeychronM3Reports.decodeReceiver(packet)?.percentage == 98)
        XCTAssertTrue(KeychronM3Reports.decodeReceiver(packet)?.powerDescription == "On battery")
        for index in [0, 1, 2, 3] {
            var invalid = packet; invalid[index] ^= 1
            XCTAssertTrue(KeychronM3Reports.decodeReceiver(invalid) == nil)
        }
        XCTAssertTrue(KeychronM3Reports.decodeReceiver(Array(packet.prefix(12))) == nil)
        var invalid = packet; invalid[5] = 101
        XCTAssertTrue(KeychronM3Reports.decodeReceiver(invalid) == nil)
        invalid = packet; invalid[7] = 30
        XCTAssertTrue(KeychronM3Reports.decodeReceiver(invalid) == nil)
        invalid = packet; invalid[14] = 0xFF
        XCTAssertTrue(KeychronM3Reports.decodeReceiver(invalid) == nil)
        invalid = packet; invalid[4] = 9
        XCTAssertTrue(KeychronM3Reports.decodeReceiver(invalid) == nil)
        let bluetooth: [String: Any] = ["Vendor ID": 0x3434, "Product ID": 0xD033,
            "Transport Type": "Bluetooth LE", "Accessory Category": "Mouse",
            "Current Capacity": 100, "Max Capacity": 100, "Power Source State": "Battery Power"]
        XCTAssertTrue(KeychronM3Reports.decodeBluetooth(bluetooth)?.percentage == 100)
        XCTAssertTrue(KeychronM3Reports.decodeBluetooth(bluetooth)?.powerDescription == "On battery")
        var accessory = bluetooth; accessory["Current Capacity"] = 0
        XCTAssertTrue(KeychronM3Reports.decodeBluetooth(accessory)?.percentage == 0)
        accessory = bluetooth; accessory["Current Capacity"] = 1; accessory["Max Capacity"] = 2
        XCTAssertTrue(KeychronM3Reports.decodeBluetooth(accessory)?.percentage == 50)
        for key in ["Vendor ID", "Product ID", "Transport Type", "Accessory Category", "Max Capacity"] {
            accessory = bluetooth; accessory.removeValue(forKey: key)
            XCTAssertTrue(KeychronM3Reports.decodeBluetooth(accessory) == nil)
        }
        accessory = bluetooth; accessory["Product ID"] = 0x1234
        XCTAssertTrue(KeychronM3Reports.decodeBluetooth(accessory) == nil)
        accessory = bluetooth; accessory["Current Capacity"] = 101
        XCTAssertTrue(KeychronM3Reports.decodeBluetooth(accessory) == nil)
        accessory = bluetooth; accessory["Max Capacity"] = 0
        XCTAssertTrue(KeychronM3Reports.decodeBluetooth(accessory) == nil)
        accessory = bluetooth; accessory["Power Source State"] = nil
        XCTAssertTrue(KeychronM3Reports.decodeBluetooth(accessory)?.powerState == nil)
        accessory = bluetooth; accessory["Is Charging"] = true
        XCTAssertTrue(KeychronM3Reports.decodeBluetooth(accessory)?.powerDescription == "Charging")
        XCTAssertTrue(KeychronM3Driver.identify(vendorID: 0x3434, productID: 0xD033, transport: "USB", usagePage: 140, usage: 1) == .cable)
        XCTAssertTrue(KeychronM3Driver.identify(vendorID: 0x3434, productID: 0xD031, transport: "USB", usagePage: 140, usage: 1) == .receiver)
        XCTAssertTrue(KeychronM3Driver.identify(vendorID: 0x3434, productID: 0xD033, transport: "Bluetooth Low Energy", usagePage: 1, usage: 2) == .bluetooth)
        XCTAssertTrue(KeychronM3Driver.identify(vendorID: 0x3434, productID: 0xD033, transport: "USB", usagePage: 1, usage: 2) == nil)
        XCTAssertTrue(KeychronM3Driver.identify(vendorID: 0x1234, productID: 0xD033, transport: "Bluetooth", usagePage: 1, usage: 2) == nil)
        let available: [ConnectionMode] = [.receiver, .bluetooth]
        XCTAssertTrue(ConnectionMode.priority.first(where: available.contains) == .bluetooth)
        XCTAssertTrue(ConnectionMode.priority.first(where: [.receiver, .cable, .bluetooth].contains) == .cable)
        print("USB/receiver decoding, Bluetooth battery, and connection-mode checks passed.")
    }
}
