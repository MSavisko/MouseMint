import XCTest
import Foundation

private final class MemoryPreferences: ScrollingPreferences {
    var automaticallySwitch = true
}

private final class FakeScrolling: NaturalScrollingBackend {
    var state: NaturalScrollingState
    var writes: [Bool] = []
    var fail = false
    init(_ enabled: Bool) { state = NaturalScrollingState(preference: enabled, live: enabled) }
    func read() -> NaturalScrollingState { state }
    func setEnabled(_ enabled: Bool) throws {
        writes.append(enabled)
        if fail { throw NaturalScrollingError.applyFailed }
        state = NaturalScrollingState(preference: enabled, live: enabled)
    }
}

final class NaturalScrollingTests: XCTestCase {
    func testBehavior() {
        let backend = FakeScrolling(true)
        let preferences = MemoryPreferences()
        let controller = AutomaticNaturalScrolling(backend: backend, preferences: preferences)
        controller.update(connection: .unknown)
        XCTAssertTrue(backend.writes.isEmpty)
        controller.update(connection: .connected)
        XCTAssertTrue(backend.writes == [false])
        XCTAssertTrue(controller.state.live == false)
        controller.update(connection: .connected)
        controller.update(connection: .unknown)
        XCTAssertTrue(backend.writes == [false])
        controller.update(connection: .disconnected)
        XCTAssertTrue(backend.writes == [false, true])
        controller.update(connection: .unknown)
        XCTAssertTrue(controller.state.live == true)
        controller.update(connection: .connected)
        XCTAssertTrue(backend.writes == [false, true, false])

        // Repair mismatched saved/live settings, even if one is already correct.
        backend.state = NaturalScrollingState(preference: false, live: true)
        controller.update(connection: .connected)
        XCTAssertTrue(controller.state == NaturalScrollingState(preference: false, live: false))
        backend.state = NaturalScrollingState(preference: true, live: false)
        controller.update(connection: .disconnected)
        XCTAssertTrue(controller.state == NaturalScrollingState(preference: true, live: true))

        // Failed writes stay visible and retry on the next confirmed observation.
        backend.fail = true
        controller.update(connection: .connected)
        XCTAssertTrue(controller.errorMessage != nil && controller.state.live == true)
        controller.update(connection: .unknown)
        XCTAssertTrue(controller.errorMessage != nil)
        backend.fail = false
        controller.update(connection: .connected)
        XCTAssertTrue(controller.errorMessage == nil && controller.state.live == false)

        // Turning automation off leaves the setting untouched through all
        // connection changes, including a query that was already in flight.
        let beforeDisable = backend.writes
        controller.setAutomatic(false)
        for connection: MouseConnectionState in [.disconnected, .connected, .unknown] {
            controller.update(connection: connection)
        }
        XCTAssertTrue(backend.writes == beforeDisable && controller.state.live == false)
        XCTAssertTrue(controller.menuTitle.contains("manual"))
        let reopened = AutomaticNaturalScrolling(backend: backend, preferences: preferences)
        XCTAssertTrue(!reopened.isAutomatic)
        reopened.setManual(true)
        XCTAssertTrue(reopened.state.live == true)
        reopened.update(connection: .connected)
        XCTAssertTrue(reopened.state.live == true)
        backend.fail = true
        reopened.setManual(false)
        XCTAssertTrue(reopened.errorMessage != nil)
        backend.fail = false
        reopened.setAutomatic(true)
        XCTAssertTrue(reopened.state.live == true && reopened.errorMessage == nil)
        reopened.setManual(false) // Manual controls cannot override automation.
        XCTAssertTrue(reopened.state.live == true)
        reopened.update(connection: .connected)
        XCTAssertTrue(reopened.state.live == false)

        XCTAssertTrue(MouseReadError.disconnected.scrollingConnection(directMousePresent: false) == .disconnected)
        XCTAssertTrue(MouseReadError.receiverDisconnected.scrollingConnection(directMousePresent: false) == .disconnected)
        for error: MouseReadError in [.receiverUnavailable, .invalid, .access(-1), .request(-1), .response(-1)] {
            XCTAssertTrue(error.scrollingConnection(directMousePresent: false) == .unknown)
            XCTAssertTrue(error.scrollingConnection(directMousePresent: true) == .connected)
        }
        // A mouse appearing while a failed query completes wins over that failure.
        XCTAssertTrue(MouseReadError.disconnected.scrollingConnection(directMousePresent: true) == .connected)
        var noTarget = [UInt8](repeating: 0, count: 21)
        noTarget[0] = 0x54; noTarget[1] = 0xE4; noTarget[2] = 2
        XCTAssertTrue(KeychronM3Reports.hasNoTarget(noTarget))
        XCTAssertTrue(!KeychronM3Reports.hasNoTarget(Array(noTarget.prefix(3))))
        for result: UInt8 in [0, 1, 3, 255] {
            var other = noTarget; other[2] = result
            XCTAssertTrue(!KeychronM3Reports.hasNoTarget(other))
        }
        var malformed = noTarget; malformed[8] = 99
        XCTAssertTrue(!KeychronM3Reports.hasNoTarget(malformed))
        print("Natural Scrolling connection, failure, retry, and persistence checks passed.")
    }
}
