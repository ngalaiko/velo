import Foundation

/// Links MCU monotonic time to wall clock time.
/// Set once on the first valid GPS fix; used to reconstruct absolute timestamps.
struct GpsAnchor {
    let monotonicMs: UInt64
    let wallClockDate: Date

    func date(forMonotonicMs ms: UInt64) -> Date {
        let offsetSeconds = Double(Int64(bitPattern: ms) - Int64(bitPattern: monotonicMs)) / 1000.0
        return wallClockDate.addingTimeInterval(offsetSeconds)
    }
}
