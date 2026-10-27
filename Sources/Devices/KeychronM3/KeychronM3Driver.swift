import Foundation

struct KeychronM3Driver: MouseDeviceDriver {
    let access: HIDAccess
    let accessory: AccessoryBatterySource
    let timing: DeviceReadTiming
    var descriptor: DeviceDescriptor { .init(name: "Keychron M3", transports: [.cable, .receiver, .bluetooth], capabilities: [.battery, .powerStatus]) }
    func match(_ endpoint: DeviceEndpoint) -> ConnectionMode? {
        Self.identify(vendorID: endpoint.vendorID, productID: endpoint.productID,
            transport: endpoint.transport, usagePage: endpoint.usagePage, usage: endpoint.usage)
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

    func read(_ endpoint: DeviceEndpoint, mode: ConnectionMode) throws -> MouseReading {
        if mode == .bluetooth {
            let status = accessory.records().compactMap(KeychronM3Reports.decodeBluetooth).first
            return MouseReading(date: timing.date(), status: status, rawReport: [], mode: mode, productID: endpoint.productID)
        }
        let session = try access.open(endpoint)
        defer { session.close() }
        let result: (BatteryStatus, [UInt8])
        if mode == .receiver { result = try receiver(session) }
        else { result = try wired(session) }
        return MouseReading(date: timing.date(), status: result.0, rawReport: result.1, mode: mode, productID: endpoint.productID)
    }
    private func wired(_ session: HIDSession) throws -> (BatteryStatus, [UInt8]) {
        try session.sendFeatureReport([0x51, 6] + Array(repeating: 0, count: 19))
        var lastError: Error?
        for _ in 0..<3 {
            do {
                let report = try session.featureReport(id: 0x51, length: 21)
                lastError = nil
                if let status = KeychronM3Reports.decodeWired(report) { return (status, report) }
            } catch { lastError = error }
            timing.sleep(0.02)
        }
        if let lastError { throw lastError }
        throw MouseReadError.invalid
    }
    private func receiver(_ session: HIDSession) throws -> (BatteryStatus, [UInt8]) {
        let state = ReceiverObservation()
        session.receiveInput { report in
            if KeychronM3Reports.decodeReceiver(report) != nil { state.report = report }
            if KeychronM3Reports.hasNoTarget(report) { state.disconnected = true }
        }
        try session.sendFeatureReport([0x51, 0x0C, 2] + Array(repeating: 0, count: 18))
        let deadline = timing.now() + 1.2
        while state.report == nil, !state.disconnected, timing.now() < deadline { session.pumpInput(for: 0.03) }
        if state.disconnected { throw MouseReadError.receiverDisconnected }
        guard let report = state.report, let status = KeychronM3Reports.decodeReceiver(report) else { throw MouseReadError.receiverUnavailable }
        return (status, report)
    }
}

private final class ReceiverObservation { var report: [UInt8]?; var disconnected = false }
