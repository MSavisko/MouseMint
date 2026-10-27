import XCTest

final class ScrollingPolicyTests: XCTestCase {
    func testConnectedAndDisconnectedDesiredStates() {
        XCTAssertEqual(ScrollingPolicy.desiredState(connection: .connected, automatic: true), false)
        XCTAssertEqual(ScrollingPolicy.desiredState(connection: .disconnected, automatic: true), true)
    }
    func testUnknownConnectionLeavesTheCurrentSettingAlone() {
        XCTAssertNil(ScrollingPolicy.desiredState(connection: .unknown, automatic: true))
    }
    func testDisabledAutomationNeverRequestsASettingChange() {
        for connection: MouseConnectionState in [.connected, .disconnected, .unknown] {
            XCTAssertNil(ScrollingPolicy.desiredState(connection: connection, automatic: false))
        }
    }
}
