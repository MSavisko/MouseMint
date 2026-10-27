import Foundation
import IOKit.ps
import Darwin

struct AccessoryBatterySession {
    let read: () -> [[String: Any]]
    let close: () -> Void
}
struct SystemAccessoryBatterySource: AccessoryBatterySource {
    private let load: () -> AccessoryBatterySession?
    init(load: @escaping () -> AccessoryBatterySession? = SystemAccessoryBatterySource.nativeSession) { self.load = load }
    func records() -> [[String: Any]] {
        guard let session = load() else { return [] }
        defer { session.close() }
        return session.read()
    }
    static func nativeSession() -> AccessoryBatterySession? {
        // Unsupported accessory SPI: absence leaves battery data unavailable.
        guard let library = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY) else { return nil }
        guard let symbol = dlsym(library, "IOPSCopyPowerSourcesByType") else { dlclose(library); return nil }
        typealias CopySources = @convention(c) (Int32) -> Unmanaged<CFTypeRef>?
        let copy = unsafeBitCast(symbol, to: CopySources.self)
        // kIOPSSourceForAccessories = 4, from Apple's IOPowerSourcesPrivate.h.
        return AccessoryBatterySession(read: {
        guard let blob = copy(4)?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return [] }
        return sources.compactMap { IOPSGetPowerSourceDescription(blob, $0)?.takeUnretainedValue() as? [String: Any] }
        }, close: { dlclose(library) })
    }
}
