import Foundation
import IOKit.hid

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x3434, kIOHIDProductIDKey: 0xD033, kIOHIDPrimaryUsagePageKey: 0x8C] as CFDictionary)
let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
print("Matching devices: \(devices.count)")
for device in devices {
    let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
    print(String(format: "Open: 0x%08x", result))
    guard result == kIOReturnSuccess else { continue }
    defer { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
    var request = [UInt8](repeating: 0, count: 21)
    request[0] = 0x51
    request[1] = 0x06
    let sent = IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, 0x51, request, request.count)
    print(String(format: "Request basic status 51 06: 0x%08x", sent))
    for (reportID, size) in [(0x51, 21)] {
            var bytes = [UInt8](repeating: 0, count: size)
            bytes[0] = UInt8(reportID)
            var length = bytes.count
            let status = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, CFIndex(reportID), &bytes, &length)
            print(String(format: "GetReport %02x: 0x%08x, size: %d, length: %d", reportID, status, size, length))
            print(bytes.prefix(length).map { String(format: "%02x", $0) }.joined(separator: " "))
            Thread.sleep(forTimeInterval: 0.2)
    }
    let input = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    defer { input.deallocate() }
    IOHIDDeviceRegisterInputReportCallback(device, input, 64, { _, result, _, _, reportID, report, length in
        print("Input \(reportID): " + UnsafeBufferPointer(start: report, count: length).map { String(format: "%02x", $0) }.joined(separator: " "))
        fflush(stdout)
    }, nil)
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    print("Listening for battery events for 2 seconds...")
    fflush(stdout)
    CFRunLoopRunInMode(.defaultMode, 2, false)
    IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
}
