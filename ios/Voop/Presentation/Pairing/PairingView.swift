import SwiftUI

struct PairingView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isScanning = false

    var body: some View {
        List {
            Section {
                Button(isScanning ? "Stop Scanning" : "Scan for Sensors") {
                    if isScanning {
                        appModel.ble.stopScan()
                    } else {
                        appModel.ble.startScan()
                    }
                    isScanning.toggle()
                }
            }
        }
        .navigationTitle("Pair Sensor")
    }
}
