// Research probe for D031 status events; no mouse settings are changed.
import Foundation
import IOKit.hid

let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x3434, kIOHIDProductIDKey: 0xD031, kIOHIDPrimaryUsagePageKey: 0x8C] as CFDictionary)
let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
print("Matching devices: \(devices.count)")
for device in devices {
    let result = IOHIDDeviceOpen(device, 0)
    print(String(format: "Open: 0x%08x", result))
    guard result == kIOReturnSuccess else { continue }
    print("Product ID: \(IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString)!)")
    let input = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    IOHIDDeviceRegisterInputReportCallback(device, input, 64, { _, _, _, _, reportID, report, length in
        print("Input \(reportID): " + UnsafeBufferPointer(start: report, count: length).map { String(format: "%02x", $0) }.joined(separator: " "))
        fflush(stdout)
    }, nil)
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    for command: UInt8 in [0x0C] {
        var request = [UInt8](repeating: 0, count: 21)
        request[0] = 0x51
        request[1] = command
        if command == 0x0C { request[2] = 2 }
        let sent = IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, 0x51, request, request.count)
        print(String(format: "Request 51 %02x: 0x%08x", command, sent))
        CFRunLoopRunInMode(.defaultMode, 2, false)
    }

    IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    IOHIDDeviceClose(device, 0)
    input.deallocate()
}
