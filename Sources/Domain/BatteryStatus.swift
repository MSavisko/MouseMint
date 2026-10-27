import Foundation

struct BatteryStatus: Equatable, Codable {
    let percentage: Int
    let powerState: UInt8?
    let usbRevision: UInt16?

}
