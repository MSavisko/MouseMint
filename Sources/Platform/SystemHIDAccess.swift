import Foundation
import IOKit
import IOKit.hid

/// Used only on the reader's serial worker (or a synchronous diagnostic run).
final class SystemHIDAccess: HIDAccess {
    private var handles: [UInt64: IOHIDDevice] = [:]
    func devices() -> [DeviceEndpoint] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        IOHIDManagerSetDeviceMatching(manager, nil)
        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        var next: [UInt64: IOHIDDevice] = [:]
        let endpoints = devices.compactMap { device -> DeviceEndpoint? in
            var id: UInt64 = 0
            let service = IOHIDDeviceGetService(device)
            guard service != 0, IORegistryEntryGetRegistryEntryID(service, &id) == 0 else { return nil }
            func number(_ key: String) -> Int { (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0 }
            next[id] = device
            return DeviceEndpoint(id: id, vendorID: number(kIOHIDVendorIDKey), productID: number(kIOHIDProductIDKey),
                transport: IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? "",
                usagePage: number(kIOHIDPrimaryUsagePageKey), usage: number(kIOHIDPrimaryUsageKey))
        }
        handles = next
        return endpoints
    }
    func open(_ endpoint: DeviceEndpoint) throws -> HIDSession {
        guard let device = handles[endpoint.id] else { throw MouseReadError.disconnected }
        let runLoop = CFRunLoopGetCurrent()!
        let operations = HIDNativeOperations(
            open: { IOHIDDeviceOpen(device, 0) }, close: { _ = IOHIDDeviceClose(device, 0) },
            send: { bytes in
                guard let id = bytes.first else { return kIOReturnBadArgument }
                return IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, CFIndex(id), bytes, bytes.count)
            },
            get: { id, capacity in
                guard capacity > 0 else { return (kIOReturnBadArgument, []) }
                var bytes = [UInt8](repeating: 0, count: capacity)
                bytes[0] = id
                var length = capacity
                let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, CFIndex(id), &bytes, &length)
                return (result, length >= 0 && length <= capacity ? Array(bytes.prefix(length)) : [])
            },
            register: { buffer, capacity, handler in
                let context = Unmanaged.passUnretained(handler).toOpaque()
                IOHIDDeviceRegisterInputReportCallback(device, buffer, capacity, { context, result, _, _, _, bytes, length in
                    guard result == kIOReturnSuccess, let context, length > 0, length <= 64 else { return }
                    let handler = Unmanaged<HIDInputHandler>.fromOpaque(context).takeUnretainedValue()
                    handler.receive(Array(UnsafeBufferPointer(start: bytes, count: length)))
                }, context)
            },
            schedule: { IOHIDDeviceScheduleWithRunLoop(device, runLoop, CFRunLoopMode.defaultMode.rawValue) },
            unschedule: { IOHIDDeviceUnscheduleFromRunLoop(device, runLoop, CFRunLoopMode.defaultMode.rawValue) },
            unregister: { buffer in IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, nil, nil) },
            pump: { seconds in CFRunLoopRunInMode(.defaultMode, seconds, true) })
        return try NativeHIDSession(operations: operations)
    }
}
