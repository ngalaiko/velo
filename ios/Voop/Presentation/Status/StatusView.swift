import SwiftUI

struct StatusView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        List {
            Section("Device") {
                LabeledContent("Connection") {
                    Text(connectionLabel)
                        .foregroundStyle(connectionColor)
                }
                LabeledContent("GPS") {
                    Text(gpsLabel)
                        .foregroundStyle(gpsColor)
                }
                LabeledContent("Cadence Sensor") {
                    Text(appModel.ble.deviceStatus.cadenceSensorConnected ? "Connected" : "Not connected")
                        .foregroundStyle(appModel.ble.deviceStatus.cadenceSensorConnected ? .green : .secondary)
                }
                if let battery = appModel.ble.deviceStatus.batteryPercent {
                    LabeledContent("Cadence Sensor Battery", value: "\(battery)%")
                }
            }

            Section("Buffer") {
                LabeledContent("Pending points", value: "\(appModel.pendingPoints.count)")
            }
        }
        .navigationTitle("Status")
    }

    private var connectionLabel: String {
        switch appModel.ble.connectionState {
        case .idle: "Idle"
        case .scanning: "Scanning…"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .disconnected: "Disconnected"
        }
    }

    private var connectionColor: Color {
        switch appModel.ble.connectionState {
        case .connected: .green
        case .disconnected: .red
        default: .secondary
        }
    }

    private var gpsLabel: String {
        switch appModel.ble.deviceStatus.gpsFix {
        case .none: "No fix"
        case .acquiring: "Acquiring…"
        case .fixed: "Fixed"
        }
    }

    private var gpsColor: Color {
        switch appModel.ble.deviceStatus.gpsFix {
        case .fixed: .green
        case .acquiring: .orange
        case .none: .secondary
        }
    }
}
