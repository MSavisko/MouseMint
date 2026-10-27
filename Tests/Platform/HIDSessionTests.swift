import XCTest

final class HIDSessionTests: XCTestCase {
    func testNativeCleanupKeepsHandlerAliveThroughCloseAndIsIdempotent() throws {
        var events: [String] = []
        weak var handler: HIDInputHandler?
        let operations = HIDNativeOperations(open: { events.append("open"); return 0 },
            close: { XCTAssertNotNil(handler); events.append("close") },
            send: { _ in 0 }, get: { _, _ in (0, []) },
            register: { _, count, value in XCTAssertEqual(count, 64); handler = value; events.append("register") },
            schedule: { events.append("schedule") }, unschedule: { events.append("unschedule") },
            unregister: { _ in XCTAssertNotNil(handler); events.append("unregister") }, pump: { _ in })
        let session = try NativeHIDSession(operations: operations)
        session.receiveInput { _ in }
        XCTAssertNotNil(handler)
        session.close(); session.close()
        XCTAssertEqual(events, ["open", "register", "schedule", "unschedule", "unregister", "close"])
        XCTAssertNil(handler)
    }
    func testNativeErrorsAndUnopenedSessionDoNotLeak() throws {
        var closes = 0
        var operations = HIDNativeOperations(open: { -1 }, close: { closes += 1 },
            send: { _ in -2 }, get: { _, _ in (-3, []) }, register: { _, _, _ in },
            schedule: {}, unschedule: {}, unregister: { _ in }, pump: { _ in })
        XCTAssertThrowsError(try NativeHIDSession(operations: operations)) { XCTAssertEqual($0 as? MouseReadError, .access(-1)) }
        XCTAssertEqual(closes, 0)
        operations.open = { 0 }
        var session: NativeHIDSession? = try NativeHIDSession(operations: operations)
        XCTAssertThrowsError(try session!.sendFeatureReport([0x51])) { XCTAssertEqual($0 as? MouseReadError, .request(-2)) }
        XCTAssertThrowsError(try session!.featureReport(id: 0x51, length: 21)) { XCTAssertEqual($0 as? MouseReadError, .response(-3)) }
        session = nil
        XCTAssertEqual(closes, 1)
    }
}
