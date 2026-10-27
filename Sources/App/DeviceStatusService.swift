import Foundation

struct DeviceStatusService: MouseStatusReading {
    let access: HIDAccess
    let drivers: [MouseDeviceDriver]
    var deviceName: String { drivers.first?.descriptor.name ?? "Mouse" }
    func read() throws -> MouseReading {
        let endpoints = access.devices()
        for mode in ConnectionMode.priority {
            for endpoint in endpoints {
                if let driver = drivers.first(where: { $0.match(endpoint) == mode }) {
                    var reading = try driver.read(endpoint, mode: mode)
                    reading.deviceName = driver.descriptor.name
                    return reading
                }
            }
        }
        throw MouseReadError.disconnected
    }
    func hasDirectConnection() -> Bool {
        access.devices().contains { endpoint in
            drivers.contains { driver in
                let mode = driver.match(endpoint)
                return mode == .cable || mode == .bluetooth
            }
        }
    }
}
