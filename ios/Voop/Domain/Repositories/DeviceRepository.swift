import Foundation

struct DeviceStatus {
    enum GPSFix { case none, acquiring, fixed }
    let gpsFix: GPSFix
    let cadenceSensorConnected: Bool
    let batteryPercent: UInt8?
}

protocol DeviceRepository: Sendable {
    var status: DeviceStatus { get }
    var dataPoints: AsyncStream<DataPoint> { get }
    func startScan() async
    func stopScan() async
    func pairSensor(address: String) async throws
}
