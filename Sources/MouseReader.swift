import Foundation
import IOKit.hid

enum MouseReadError: Error, CustomStringConvertible {
    case disconnected, receiverUnavailable, access(IOReturn), request(IOReturn), response(IOReturn), invalid

    var description: String {
        switch self {
        case .disconnected: return "Connect your M3 by cable, receiver, or Bluetooth."
        case .receiverUnavailable: return "Receiver connected; mouse asleep, disconnected, or not responding."
        case .access(let code): return "USB access denied or busy (\(Self.hex(code))). Close Keychron Engine and reopen this app."
        case .request(let code): return "Status request failed (\(Self.hex(code))). Reconnect the mouse."
        case .response(let code): return "Status read failed (\(Self.hex(code))). Reconnect the mouse."
        case .invalid: return "The mouse returned an unrecognized status. Battery level is unavailable."
        }
    }
    private static func hex(_ value: IOReturn) -> String { String(format: "0x%08x", value) }
}

struct MouseReading: Codable {
    let date: Date
    let status: BatteryStatus?
    let rawReport: [UInt8]
    let mode: ConnectionMode
    let productID: Int
}

enum MouseReader {
    static func read() throws -> MouseReading {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x3434] as CFDictionary)
        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        let productID: (IOHIDDevice) -> Int = {
            (IOHIDDeviceGetProperty($0, kIOHIDProductIDKey as CFString) as? NSNumber)?.intValue ?? 0
        }
        let mode: (IOHIDDevice) -> ConnectionMode? = { device in
            func number(_ key: String) -> Int {
                (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0
            }
            return ConnectionMode.identify(vendorID: number(kIOHIDVendorIDKey), productID: productID(device),
                transport: IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? "",
                usagePage: number(kIOHIDPrimaryUsagePageKey), usage: number(kIOHIDPrimaryUsageKey))
        }
        guard let selectedMode = ConnectionMode.priority.first(where: { candidate in devices.contains(where: { mode($0) == candidate }) }),
              let device = devices.first(where: { mode($0) == selectedMode }) else { throw MouseReadError.disconnected }
        if selectedMode == .bluetooth {
            return MouseReading(date: Date(), status: BluetoothBatteryReader.read(), rawReport: [], mode: .bluetooth, productID: productID(device))
        }
        if selectedMode == .receiver {
            let (status, report) = try ReceiverReader.read(device)
            return MouseReading(date: Date(), status: status, rawReport: report, mode: .receiver, productID: productID(device))
        }
        let opened = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard opened == kIOReturnSuccess else { throw MouseReadError.access(opened) }
        defer { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }

        // Keychron Engine 1.0.10: GetMouseData -> SetDeviceData ->
        // hid_send_feature_report([0x51, 0x06, 0...], 21), then GET_REPORT.
        // 0x06 requests basic status; this does not write mouse configuration.
        var request = [UInt8](repeating: 0, count: 21)
        request[0] = 0x51
        request[1] = 0x06
        let sent = IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, 0x51, request, request.count)
        guard sent == kIOReturnSuccess else { throw MouseReadError.request(sent) }
        var lastCode = kIOReturnSuccess
        for _ in 0..<3 {
            var report = [UInt8](repeating: 0, count: 21)
            report[0] = 0x51
            var length = report.count
            lastCode = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 0x51, &report, &length)
            if lastCode == kIOReturnSuccess,
               let status = BatteryStatus.decode(Array(report.prefix(length))) {
                return MouseReading(date: Date(), status: status, rawReport: Array(report.prefix(length)), mode: .cable, productID: productID(device))
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        if lastCode != kIOReturnSuccess { throw MouseReadError.response(lastCode) }
        throw MouseReadError.invalid
    }
}
