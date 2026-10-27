import XCTest

final class AccessorySourceTests: XCTestCase {
    func testUnavailableNativeServiceReturnsNoRecords() {
        XCTAssertTrue(SystemAccessoryBatterySource(load: { nil }).records().isEmpty)
    }
    func testNativeSessionIsClosedAfterBothEmptyAndSuccessfulReads() {
        for values: [[String: Any]] in [[], [["Current Capacity": 72]]] {
            var calls: [String] = []
            let source = SystemAccessoryBatterySource(load: {
                calls.append("load")
                return AccessoryBatterySession(read: { calls.append("read"); return values }, close: { calls.append("close") })
            })
            XCTAssertEqual(source.records().count, values.count)
            XCTAssertEqual(calls, ["load", "read", "close"])
        }
    }
}
