import Foundation

enum ConnectionMode: String, Codable {
    case cable, receiver, bluetooth

    var title: String {
        switch self {
        case .cable: return "USB cable"
        case .receiver: return "2.4 GHz receiver"
        case .bluetooth: return "Bluetooth"
        }
    }

    static func identify(vendorID: Int, productID: Int, transport: String, usagePage: Int, usage: Int) -> ConnectionMode? {
        guard vendorID == 0x3434 else { return nil }
        if productID == 0xD033 && transport.hasPrefix("Bluetooth") && usagePage == 1 && usage == 2 {
            return .bluetooth
        }
        guard transport == "USB", usagePage == 0x8C, usage == 1 else { return nil }
        if productID == 0xD033 { return .cable }
        if productID == 0xD031 { return .receiver }
        return nil
    }

    static let priority: [ConnectionMode] = [.cable, .bluetooth, .receiver]
}
