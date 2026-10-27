import Foundation

final class HIDInputHandler {
    let receive: ([UInt8]) -> Void
    init(_ receive: @escaping ([UInt8]) -> Void) { self.receive = receive }
}
struct HIDNativeOperations {
    var open: () -> Int32
    var close: () -> Void
    var send: ([UInt8]) -> Int32
    var get: (UInt8, Int) -> (Int32, [UInt8])
    var register: (UnsafeMutablePointer<UInt8>, Int, HIDInputHandler) -> Void
    var schedule: () -> Void
    var unschedule: () -> Void
    var unregister: (UnsafeMutablePointer<UInt8>) -> Void
    var pump: (TimeInterval) -> Void
}
final class NativeHIDSession: HIDSession {
    private let operations: HIDNativeOperations
    private var opened = false
    private var input: UnsafeMutablePointer<UInt8>?
    private var handler: HIDInputHandler?
    init(operations: HIDNativeOperations) throws {
        self.operations = operations
        let result = operations.open()
        guard result == 0 else { throw MouseReadError.access(result) }
        opened = true
    }
    func sendFeatureReport(_ bytes: [UInt8]) throws {
        let result = operations.send(bytes)
        guard result == 0 else { throw MouseReadError.request(result) }
    }
    func featureReport(id: UInt8, length: Int) throws -> [UInt8] {
        let (result, bytes) = operations.get(id, length)
        guard result == 0 else { throw MouseReadError.response(result) }
        return bytes
    }
    func receiveInput(_ callback: @escaping ([UInt8]) -> Void) {
        precondition(opened && input == nil)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        let handler = HIDInputHandler(callback)
        self.input = buffer; self.handler = handler
        operations.register(buffer, 64, handler)
        operations.schedule()
    }
    func pumpInput(for seconds: TimeInterval) { operations.pump(seconds) }
    func close() {
        guard opened else { return }
        if let input { operations.unschedule(); operations.unregister(input) }
        operations.close()
        opened = false
        // Callback context and bytes remain alive until callbacks are removed
        // and the device is closed, including request failures and timeouts.
        handler = nil
        input?.deallocate(); input = nil
    }
    deinit { close() }
}
