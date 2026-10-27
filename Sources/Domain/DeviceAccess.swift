import Foundation

struct DeviceEndpoint {
    let id: UInt64
    let vendorID: Int
    let productID: Int
    let transport: String
    let usagePage: Int
    let usage: Int
}
enum DeviceCapability: Hashable { case battery, powerStatus }
struct DeviceDescriptor {
    let name: String
    let transports: Set<ConnectionMode>
    let capabilities: Set<DeviceCapability>
}
protocol HIDAccess {
    func devices() -> [DeviceEndpoint]
    func open(_ endpoint: DeviceEndpoint) throws -> HIDSession
}
protocol HIDSession: AnyObject {
    func sendFeatureReport(_ bytes: [UInt8]) throws
    func featureReport(id: UInt8, length: Int) throws -> [UInt8]
    func receiveInput(_ callback: @escaping ([UInt8]) -> Void)
    func pumpInput(for seconds: TimeInterval)
    func close()
}
protocol AccessoryBatterySource { func records() -> [[String: Any]] }
struct DeviceReadTiming {
    let now: () -> TimeInterval
    let sleep: (TimeInterval) -> Void
    let date: () -> Date
}
protocol MouseDeviceDriver {
    var descriptor: DeviceDescriptor { get }
    func match(_ endpoint: DeviceEndpoint) -> ConnectionMode?
    func read(_ endpoint: DeviceEndpoint, mode: ConnectionMode) throws -> MouseReading
}
