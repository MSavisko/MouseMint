import Foundation

enum ConnectionMode: String, Codable {
    case cable, receiver, bluetooth

    static let priority: [ConnectionMode] = [.cable, .bluetooth, .receiver]
}
