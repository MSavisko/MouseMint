import Foundation

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

@main struct NaturalScrollingTests {
    static func main() {
        let backend = FakeScrolling(true)
        let controller = AutomaticNaturalScrolling(backend: backend)
        controller.update(connection: .unknown)
        precondition(backend.writes.isEmpty)
        controller.update(connection: .connected)
        precondition(backend.writes == [false])
        precondition(controller.state.live == false)
        controller.update(connection: .connected)
        controller.update(connection: .unknown)
        precondition(backend.writes == [false])
        controller.update(connection: .disconnected)
        precondition(backend.writes == [false, true])
        controller.update(connection: .unknown)
        precondition(controller.state.live == true)
        controller.update(connection: .connected)
        precondition(backend.writes == [false, true, false])

        // Repair mismatched saved/live settings, even if one is already correct.
        backend.state = NaturalScrollingState(preference: false, live: true)
        controller.update(connection: .connected)
        precondition(controller.state == NaturalScrollingState(preference: false, live: false))
        backend.state = NaturalScrollingState(preference: true, live: false)
        controller.update(connection: .disconnected)
        precondition(controller.state == NaturalScrollingState(preference: true, live: true))

        // Failed writes stay visible and retry on the next confirmed observation.
        backend.fail = true
        controller.update(connection: .connected)
        precondition(controller.errorMessage != nil && controller.state.live == true)
        controller.update(connection: .unknown)
        precondition(controller.errorMessage != nil)
        backend.fail = false
        controller.update(connection: .connected)
        precondition(controller.errorMessage == nil && controller.state.live == false)

        precondition(MouseReadError.disconnected.scrollingConnection(directMousePresent: false) == .disconnected)
        precondition(MouseReadError.receiverDisconnected.scrollingConnection(directMousePresent: false) == .disconnected)
        for error: MouseReadError in [.receiverUnavailable, .invalid, .access(-1), .request(-1), .response(-1)] {
            precondition(error.scrollingConnection(directMousePresent: false) == .unknown)
            precondition(error.scrollingConnection(directMousePresent: true) == .connected)
        }
        // A mouse appearing while a failed query completes wins over that failure.
        precondition(MouseReadError.disconnected.scrollingConnection(directMousePresent: true) == .connected)
        var noTarget = [UInt8](repeating: 0, count: 21)
        noTarget[0] = 0x54; noTarget[1] = 0xE4; noTarget[2] = 2
        precondition(ReceiverReader.hasNoTarget(noTarget))
        precondition(!ReceiverReader.hasNoTarget(Array(noTarget.prefix(3))))
        for result: UInt8 in [0, 1, 3, 255] {
            var other = noTarget; other[2] = result
            precondition(!ReceiverReader.hasNoTarget(other))
        }
        var malformed = noTarget; malformed[8] = 99
        precondition(!ReceiverReader.hasNoTarget(malformed))
        print("Natural Scrolling connection, failure, retry, and persistence checks passed.")
    }
}
