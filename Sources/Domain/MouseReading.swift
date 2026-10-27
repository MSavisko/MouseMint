import Foundation

struct MouseReading: Codable {
    enum CodingKeys: String, CodingKey { case date, status, rawReport, mode, productID }
    var deviceName: String? = nil
    let date: Date
    let status: BatteryStatus?
    let rawReport: [UInt8]
    let mode: ConnectionMode
    let productID: Int
}
