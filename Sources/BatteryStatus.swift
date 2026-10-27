import Foundation

struct BatteryStatus: Equatable, Codable {
    let percentage: Int
    let powerState: UInt8?
    let usbRevision: UInt16?

    var powerDescription: String {
        switch powerState {
        case 0: return "On battery"
        case 1: return "Charging"
        case 2: return percentage == 100 ? "Fully charged" : "External power"
        case nil: return "Not reported by macOS"
        default: return "Unknown power state (\(powerState!))"
        }
    }

}
