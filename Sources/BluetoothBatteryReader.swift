import Foundation
import IOKit.ps
import Darwin

enum BluetoothBatteryReader {
    static func read() -> BatteryStatus? {
        // macOS already publishes this BLE mouse's battery as an accessory.
        // Resolve the unsupported accessory-enumeration SPI at runtime so its
        // absence on a future macOS leaves an unknown level, not a launch error.
        guard let library = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY) else { return nil }
        defer { dlclose(library) }
        guard let symbol = dlsym(library, "IOPSCopyPowerSourcesByType") else { return nil }
        typealias CopySources = @convention(c) (Int32) -> Unmanaged<CFTypeRef>?
        let copy = unsafeBitCast(symbol, to: CopySources.self)
        // kIOPSSourceForAccessories = 4, from Apple's IOPowerSourcesPrivate.h.
        guard let blob = copy(4)?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  let status = decode(description) else { continue }
            return status
        }
        return nil
    }

    static func decode(_ description: [String: Any]) -> BatteryStatus? {
        guard (description["Vendor ID"] as? NSNumber)?.intValue == 0x3434,
              (description["Product ID"] as? NSNumber)?.intValue == 0xD033,
              (description["Transport Type"] as? String)?.hasPrefix("Bluetooth") == true,
              description["Accessory Category"] as? String == "Mouse",
              let current = (description[kIOPSCurrentCapacityKey] as? NSNumber)?.doubleValue,
              let maximum = (description[kIOPSMaxCapacityKey] as? NSNumber)?.doubleValue,
              current.isFinite, maximum.isFinite, maximum > 0, current >= 0, current <= maximum else { return nil }
        let charging = description[kIOPSIsChargingKey] as? Bool
        let onBattery = description[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue
        let state: UInt8? = charging == true ? 1 : onBattery ? 0 : nil
        return BatteryStatus(percentage: Int((100 * current / maximum).rounded()), powerState: state, usbRevision: nil)
    }
}
