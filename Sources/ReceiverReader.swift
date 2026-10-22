import Foundation
import IOKit.hid

private final class ReceiverResponse {
    var report: [UInt8]?
    var unavailable = false
}

enum ReceiverReader {
    static func read(_ device: IOHIDDevice) throws -> (BatteryStatus, [UInt8]) {
        let opened = IOHIDDeviceOpen(device, 0)
        guard opened == kIOReturnSuccess else { throw MouseReadError.access(opened) }
        let state = ReceiverResponse()
        let input = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        let runLoop = CFRunLoopGetCurrent()!
        let context = Unmanaged.passUnretained(state).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, input, 64, { context, result, _, _, _, bytes, length in
            guard result == kIOReturnSuccess, let context, length > 0 else { return }
            let state = Unmanaged<ReceiverResponse>.fromOpaque(context).takeUnretainedValue()
            let report = Array(UnsafeBufferPointer(start: bytes, count: length))
            if BatteryStatus.decodeReceiver(report) != nil { state.report = report }
            if report.count >= 3, report[0] == 0x54, report[1] == 0xE4, report[2] >= 2 {
                state.unavailable = true
            }
        }, context)
        IOHIDDeviceScheduleWithRunLoop(device, runLoop, CFRunLoopMode.defaultMode.rawValue)
        defer {
            IOHIDDeviceUnscheduleFromRunLoop(device, runLoop, CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceRegisterInputReportCallback(device, input, 64, nil, nil)
            IOHIDDeviceClose(device, 0)
            input.deallocate()
        }
        var request = [UInt8](repeating: 0, count: 21)
        request[0] = 0x51
        request[1] = 0x0C
        request[2] = 2
        let sent = IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, 0x51, request, request.count)
        guard sent == kIOReturnSuccess else { throw MouseReadError.request(sent) }
        let deadline = ProcessInfo.processInfo.systemUptime + 1.2
        while state.report == nil && !state.unavailable && ProcessInfo.processInfo.systemUptime < deadline {
            CFRunLoopRunInMode(.defaultMode, 0.03, true)
        }
        guard let report = state.report, let status = BatteryStatus.decodeReceiver(report) else {
            throw MouseReadError.receiverUnavailable
        }
        return (status, report)
    }
}
