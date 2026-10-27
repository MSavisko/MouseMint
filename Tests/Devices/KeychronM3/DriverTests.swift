import XCTest

// Captured hardware responses; malformed variants below are synthetic.
let wiredCapture: [UInt8] = [0x51, 6, 1, 0, 0x34, 0x34, 0x33, 0xD0, 0x23, 1, 0, 100, 2, 0, 0, 0, 0, 0, 0, 0, 0]
let receiverCapture: [UInt8] = [0x54, 0xE3, 0, 3, 0, 98, 0, 7, 0x31, 0x2E, 0x32, 0x2E, 0x33, 0x72, 0, 0, 0, 0, 0, 0, 0]
func testEndpoint(_ mode: ConnectionMode, id: UInt64 = 1) -> DeviceEndpoint {
    DeviceEndpoint(id: id, vendorID: 0x3434, productID: mode == .receiver ? 0xD031 : 0xD033,
        transport: mode == .bluetooth ? "Bluetooth Low Energy" : "USB", usagePage: mode == .bluetooth ? 1 : 140, usage: mode == .bluetooth ? 2 : 1)
}
final class FakeHIDAccess: HIDAccess, HIDSession {
    var endpoints: [DeviceEndpoint] = []
    var events: [String] = []
    var reports: [Result<[UInt8], Error>] = [.success(wiredCapture)]
    var inputs: [[UInt8]] = [receiverCapture]
    var onInput: (([UInt8]) -> Void)?
    var openError: Error?
    var sendError: Error?
    var sent: [[UInt8]] = []
    var now: TimeInterval = 0
    var sleeps: [TimeInterval] = []
    var onOpen: (() -> Void)?
    func devices() -> [DeviceEndpoint] { endpoints }
    func open(_ endpoint: DeviceEndpoint) throws -> HIDSession {
        events.append("open:\(endpoint.id)")
        if let openError { throw openError }
        onOpen?()
        return self
    }
    func sendFeatureReport(_ bytes: [UInt8]) throws {
        events.append("send"); sent.append(bytes)
        if let sendError { throw sendError }
    }
    func featureReport(id: UInt8, length: Int) throws -> [UInt8] {
        events.append("get:\(id):\(length)")
        return try reports.removeFirst().get()
    }
    func receiveInput(_ callback: @escaping ([UInt8]) -> Void) { events.append("register"); onInput = callback }
    func pumpInput(for seconds: TimeInterval) {
        now += seconds
        if !inputs.isEmpty { onInput?(inputs.removeFirst()) }
    }
    func close() { events.append("close"); onInput = nil }
    var timing: DeviceReadTiming { .init(now: { self.now }, sleep: { self.sleeps.append($0) }, date: { Date(timeIntervalSince1970: 0) }) }
}
final class FakeAccessorySource: AccessoryBatterySource {
    var values: [[String: Any]] = []
    var reads = 0
    func records() -> [[String: Any]] { reads += 1; return values }
}

final class DriverTests: XCTestCase {
    let io = FakeHIDAccess()
    let accessory = FakeAccessorySource()
    func service() -> DeviceStatusService {
        DeviceStatusService(access: io, drivers: [KeychronM3Driver(access: io, accessory: accessory, timing: io.timing)])
    }
    func testWiredRequestAndReadAreExactAndCloseTheSession() throws {
        io.endpoints = [testEndpoint(.cable)]
        let result = try service().read()
        XCTAssertEqual(result.status?.percentage, 100)
        XCTAssertEqual(result.deviceName, "Keychron M3")
        XCTAssertEqual(result.date, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(io.sent, [[0x51, 6] + Array(repeating: 0, count: 19)])
        XCTAssertEqual(io.events, ["open:1", "send", "get:81:21", "close"])
    }
    func testMalformedWiredResponsesRetryThreeTimesThenClose() {
        io.endpoints = [testEndpoint(.cable)]
        io.reports = Array(repeating: .success([UInt8](repeating: 0, count: 21)), count: 3)
        XCTAssertThrowsError(try service().read()) { XCTAssertTrue($0 as? MouseReadError == .invalid) }
        XCTAssertEqual(io.events.filter { $0.hasPrefix("get:") }.count, 3)
        XCTAssertEqual(io.sleeps, [0.02, 0.02, 0.02])
        XCTAssertEqual(io.events.last, "close")
    }
    func testLastReadFailureAndSendFailureCloseButFailedOpenDoesNot() {
        io.endpoints = [testEndpoint(.cable)]
        io.reports = Array(repeating: .failure(MouseReadError.response(-2)), count: 3)
        XCTAssertThrowsError(try service().read()) { XCTAssertTrue($0 as? MouseReadError == .response(-2)) }
        XCTAssertEqual(io.events.last, "close")
        io.events = []; io.sendError = MouseReadError.request(-3)
        XCTAssertThrowsError(try service().read())
        XCTAssertEqual(io.events, ["open:1", "send", "close"])
        io.events = []; io.openError = MouseReadError.access(-4)
        XCTAssertThrowsError(try service().read())
        XCTAssertEqual(io.events, ["open:1"])
    }
    func testPriorityDoesNotFallBackToReceiverAfterCableFailure() {
        io.endpoints = [testEndpoint(.receiver, id: 2), testEndpoint(.cable)]
        io.sendError = MouseReadError.request(-1)
        XCTAssertThrowsError(try service().read())
        XCTAssertEqual(io.events, ["open:1", "send", "close"])
    }
    func testBluetoothMissingBatteryStaysSelectedAndStaleRecordsAreNotRead() throws {
        io.endpoints = [testEndpoint(.receiver), testEndpoint(.bluetooth, id: 2)]
        let reader = service()
        let result = try reader.read()
        XCTAssertEqual(result.mode, .bluetooth)
        XCTAssertNil(result.status)
        XCTAssertEqual(io.events, [])
        XCTAssertEqual(accessory.reads, 1)
        io.endpoints = []
        XCTAssertThrowsError(try reader.read())
        XCTAssertEqual(accessory.reads, 1)
        XCTAssertFalse(reader.hasDirectConnection())
    }
    func testReceiverRegistersBeforeRequestAndClosesOnSuccess() throws {
        io.endpoints = [testEndpoint(.receiver)]
        let result = try service().read()
        XCTAssertEqual(result.status?.percentage, 98)
        XCTAssertEqual(io.sent, [[0x51, 0x0C, 2] + Array(repeating: 0, count: 18)])
        XCTAssertEqual(io.events, ["open:1", "register", "send", "close"])
        XCTAssertNil(io.onInput)
    }
    func testReceiverNoTargetTimeoutAndSendFailureAreDistinctAndCleanUp() {
        io.endpoints = [testEndpoint(.receiver)]
        io.inputs = [[0x54, 0xE4, 2] + Array(repeating: 0, count: 18)]
        XCTAssertThrowsError(try service().read()) { XCTAssertTrue($0 as? MouseReadError == .receiverDisconnected) }
        XCTAssertNil(io.onInput)
        io.events = []; io.inputs = []; io.now = 0
        XCTAssertThrowsError(try service().read()) { XCTAssertTrue($0 as? MouseReadError == .receiverUnavailable) }
        XCTAssertGreaterThanOrEqual(io.now, 1.2)
        XCTAssertLessThan(io.now, 1.24)
        XCTAssertEqual(io.events.last, "close")
        io.sendError = MouseReadError.request(-1)
        XCTAssertThrowsError(try service().read())
        XCTAssertNil(io.onInput)
        XCTAssertEqual(io.events.last, "close")
    }
    func testReceiverIgnoresAckAndMalformedPacketsUntilAValidFrame() throws {
        io.endpoints = [testEndpoint(.receiver)]
        io.inputs = [[0x54, 0xE4] + Array(repeating: 0, count: 19), [0, 0], receiverCapture]
        XCTAssertEqual(try service().read().status?.percentage, 98)
    }
    func testUnrelatedHIDCollectionsAreNeverOpenedAndCapabilitiesAreReadOnly() {
        io.endpoints = [DeviceEndpoint(id: 1, vendorID: 0x3434, productID: 0xD033, transport: "USB", usagePage: 1, usage: 2)]
        XCTAssertThrowsError(try service().read())
        XCTAssertTrue(io.events.isEmpty)
        let driver = KeychronM3Driver(access: io, accessory: accessory, timing: io.timing)
        XCTAssertEqual(driver.descriptor.capabilities, [.battery, .powerStatus])
        XCTAssertEqual(driver.descriptor.transports, [.cable, .receiver, .bluetooth])
    }
}
