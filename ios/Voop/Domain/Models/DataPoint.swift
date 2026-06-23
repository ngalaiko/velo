import Foundation

/// A single recorded sample from the bike computer.
/// Mirrors the Rust DataPoint struct; wire format is 26 packed bytes:
///   [u64 monotonic_ms][f64 lat][f64 lon][u16 crank_revs]
struct DataPoint {
    /// Milliseconds since MCU boot (monotonic).
    let monotonicMs: UInt64
    /// nil until GPS has a fix.
    let location: (lat: Double, lon: Double)?
    /// Raw cumulative crank revolutions from the CSC sensor.
    let cumulativeCrankRevs: UInt16
}

extension DataPoint {
    static let wireSize = 26

    init?(bytes: Data) {
        guard bytes.count >= Self.wireSize else { return nil }
        monotonicMs = bytes.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt64.self).littleEndian }
        let lat = bytes.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt64.self).littleEndian }
        let lon = bytes.withUnsafeBytes { $0.load(fromByteOffset: 16, as: UInt64.self).littleEndian }
        let latDouble = Double(bitPattern: lat)
        let lonDouble = Double(bitPattern: lon)
        location = (latDouble == 0 && lonDouble == 0) ? nil : (latDouble, lonDouble)
        cumulativeCrankRevs = bytes.withUnsafeBytes { $0.load(fromByteOffset: 24, as: UInt16.self).littleEndian }
    }
}
