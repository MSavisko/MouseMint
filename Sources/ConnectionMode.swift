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

    static let priority: [ConnectionMode] = [.cable, .bluetooth, .receiver]
}
