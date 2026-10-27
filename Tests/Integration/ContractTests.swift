import XCTest
import Foundation

final class ContractTests: XCTestCase {
    private func json<T: Encodable>(_ value: T) throws -> NSDictionary {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(value)) as? NSDictionary)
    }

    func testWiredJSONContract() throws {
        var value = MouseReading(date: Date(timeIntervalSince1970: 0),
            status: BatteryStatus(percentage: 0, powerState: 0, usbRevision: 0x0123),
            rawReport: [0x51, 0x06], mode: .cable, productID: 0xD033)
        value.deviceName = "Display metadata must not alter the public JSON"
        XCTAssertEqual(try json(value), ["date": "1970-01-01T00:00:00Z",
            "status": ["percentage": 0, "powerState": 0, "usbRevision": 291],
            "rawReport": [81, 6], "mode": "cable", "productID": 53299] as NSDictionary)
    }

    func testUnavailableBatteryJSONOmitsStatusRatherThanInventingZero() throws {
        let value = MouseReading(date: Date(timeIntervalSince1970: 0), status: nil,
                                 rawReport: [], mode: .bluetooth, productID: 0xD033)
        let object = try json(value)
        XCTAssertNil(object["status"])
        XCTAssertEqual(object["mode"] as? String, "bluetooth")
        XCTAssertEqual(object["rawReport"] as? [Int], [])
    }

    func testReceiverAndOptionalPowerFieldsKeepJSONShape() throws {
        let value = MouseReading(date: Date(timeIntervalSince1970: 0),
            status: BatteryStatus(percentage: 55, powerState: nil, usbRevision: nil),
            rawReport: [], mode: .receiver, productID: 0xD031)
        let object = try json(value)
        XCTAssertEqual(object["mode"] as? String, "receiver")
        XCTAssertEqual(object["status"] as? NSDictionary, ["percentage": 55] as NSDictionary)
    }

    func testScrollingJSONPreservesUnknownAndFalse() throws {
        XCTAssertEqual(try json(NaturalScrollingState(preference: nil, live: false)), ["live": false] as NSDictionary)
        XCTAssertEqual(try json(NaturalScrollingState(preference: nil, live: nil)), [:] as NSDictionary)
    }

    func testAllTransportPriorityCombinations() {
        let all: [ConnectionMode] = [.receiver, .bluetooth, .cable]
        for mask in 0..<8 {
            let available = all.enumerated().filter { mask & (1 << $0.offset) != 0 }.map(\.element)
            let expected: ConnectionMode? = available.contains(.cable) ? .cable : available.contains(.bluetooth) ? .bluetooth : available.contains(.receiver) ? .receiver : nil
            XCTAssertEqual(ConnectionMode.priority.first(where: available.contains), expected)
        }
    }

    func testUnrelatedCollectionsAndVendorsNeverMatch() {
        for pid in [0xD033, 0xD031] {
            XCTAssertNil(KeychronM3Driver.identify(vendorID: 0x3434, productID: pid, transport: "USB", usagePage: 1, usage: 2))
            XCTAssertNil(KeychronM3Driver.identify(vendorID: 0x1234, productID: pid, transport: "USB", usagePage: 140, usage: 1))
        }
        XCTAssertNil(KeychronM3Driver.identify(vendorID: 0x3434, productID: 0xD030, transport: "USB", usagePage: 140, usage: 1))
    }

    func testUnknownPowerValueRemainsVisible() {
        XCTAssertEqual(BatteryStatus(percentage: 0, powerState: 255, usbRevision: nil).powerDescription, "Unknown power state (255)")
        XCTAssertEqual(BatteryStatus(percentage: 0, powerState: nil, usbRevision: nil).powerDescription, "Not reported by macOS")
    }

    func testNonfiniteBluetoothCapacitiesAreRejected() {
        for value in [Double.nan, .infinity, -.infinity] {
            var record: [String: Any] = ["Vendor ID": 0x3434, "Product ID": 0xD033,
                "Transport Type": "Bluetooth LE", "Accessory Category": "Mouse",
                "Current Capacity": value, "Max Capacity": 100]
            XCTAssertNil(KeychronM3Reports.decodeBluetooth(record))
            record["Current Capacity"] = 20
            record["Max Capacity"] = value
            XCTAssertNil(KeychronM3Reports.decodeBluetooth(record))
        }
    }

    func testDirectMousePresenceWinsOverEveryReadFailure() {
        for error: MouseReadError in [.disconnected, .receiverDisconnected, .receiverUnavailable, .invalid, .access(-1), .request(-1), .response(-1)] {
            XCTAssertTrue(error.scrollingConnection(directMousePresent: true) == .connected)
        }
    }

    func testInvalidStoredIntervalsFallBackWithoutRewritingStorage() {
        let domain = "io.github.msavisko.mousemint.contract.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        for invalid in [-1, 0, 1, 4, 999] {
            defaults.set(invalid, forKey: "statusCheckIntervalSeconds")
            XCTAssertEqual(StatusPollingPreferences(defaults: defaults).seconds, 5)
            XCTAssertEqual(defaults.integer(forKey: "statusCheckIntervalSeconds"), invalid)
        }
    }

    func testPollingOwnerInvalidatesItsTimerOnRelease() {
        let domain = "io.github.msavisko.mousemint.timer.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        var polling: StatusPolling? = StatusPolling(preferences: StatusPollingPreferences(defaults: defaults), refresh: {})
        polling!.start()
        let timer = polling!.timer!
        XCTAssertTrue(timer.isValid)
        weak var owner = polling
        polling = nil
        XCTAssertNil(owner)
        XCTAssertFalse(timer.isValid)
    }
}
