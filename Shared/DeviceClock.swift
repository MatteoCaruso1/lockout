import Darwin
import Foundation
import LockoutCore

/// Reads both clocks at once (see `ClockReading`).
enum DeviceClock {
    static func read() -> ClockReading {
        // CLOCK_MONOTONIC on Apple platforms keeps counting while the phone
        // sleeps and cannot be changed from Settings. It restarts at boot.
        let seconds = TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1_000_000_000
        return ClockReading(wall: Date(), continuous: seconds, bootID: bootID)
    }

    /// Changes on every restart. If it cannot be read, each process gets its
    /// own random id, which simply makes every comparison fall back to the
    /// wall clock: less protection against clock changes, never a stuck lock.
    static let bootID: String = {
        var size = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 0 else {
            return "unknown-" + UUID().uuidString
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.bootsessionuuid", &buffer, &size, nil, 0) == 0 else {
            return "unknown-" + UUID().uuidString
        }
        return String(cString: buffer)
    }()
}
