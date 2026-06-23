@preconcurrency import CoreBluetooth
import Foundation

private nonisolated(unsafe) let mcuServiceUUID = CBUUID(string: "TODO-REPLACE-WITH-REAL-UUID")
private nonisolated(unsafe) let statusCharUUID = CBUUID(string: "TODO-REPLACE-WITH-REAL-UUID")
private nonisolated(unsafe) let sensorControlCharUUID = CBUUID(string: "TODO-REPLACE-WITH-REAL-UUID")
private nonisolated(unsafe) let dataTransferCharUUID = CBUUID(string: "TODO-REPLACE-WITH-REAL-UUID")

final class MCUPeripheral: NSObject, CBPeripheralDelegate, @unchecked Sendable {
    var onDataPoint: (@MainActor (DataPoint) -> Void)?
    var onStatusUpdate: (@MainActor (DeviceStatus) -> Void)?

    private let peripheral: CBPeripheral

    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
    }

    func discoverServices() {
        peripheral.discoverServices([mcuServiceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: (any Error)?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == mcuServiceUUID }) else { return }
        peripheral.discoverCharacteristics([statusCharUUID, dataTransferCharUUID], for: service)
        peripheral.maximumWriteValueLength(for: .withResponse)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error _: (any Error)?) {
        guard let chars = service.characteristics else { return }
        for char in chars {
            if char.uuid == statusCharUUID || char.uuid == dataTransferCharUUID {
                peripheral.setNotifyValue(true, for: char)
            }
        }
    }

    func peripheral(
        _: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard error == nil, let data = characteristic.value else { return }
        if characteristic.uuid == dataTransferCharUUID {
            if let point = DataPoint(bytes: data) {
                let cb = onDataPoint
                Task { @MainActor in cb?(point) }
            }
        } else if characteristic.uuid == statusCharUUID {
            if let status = parseStatus(data) {
                let cb = onStatusUpdate
                Task { @MainActor in cb?(status) }
            }
        }
    }

    private func parseStatus(_ data: Data) -> DeviceStatus? {
        // Wire format TBD alongside MCU peripheral implementation.
        // Placeholder: byte 0 = gps flags, byte 1 = cadence connected, byte 2 = battery
        guard data.count >= 3 else { return nil }
        let gpsFix: DeviceStatus.GPSFix = switch data[0] {
        case 0: .none
        case 1: .acquiring
        default: .fixed
        }
        return DeviceStatus(
            gpsFix: gpsFix,
            cadenceSensorConnected: data[1] != 0,
            batteryPercent: data[2]
        )
    }
}
