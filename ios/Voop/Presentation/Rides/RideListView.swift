import SwiftUI

struct RideListView: View {
    @Environment(AppModel.self) private var appModel
    @State private var savedRides: [Ride] = []

    var body: some View {
        List(savedRides) { ride in
            NavigationLink(value: ride) {
                RideRow(ride: ride)
            }
        }
        .navigationTitle("Rides")
        .navigationDestination(for: Ride.self) { ride in
            RideDetailView(ride: ride)
        }
        .task {
            savedRides = (try? await appModel.rides.fetchAll()) ?? []
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Sync") {
                    Task { await appModel.syncAndSave() }
                }
                .disabled(appModel.pendingPoints.isEmpty)
            }
        }
    }
}

private struct RideRow: View {
    let ride: Ride

    var body: some View {
        VStack(alignment: .leading) {
            Text(ride.startDate.formatted(date: .abbreviated, time: .shortened))
                .font(.headline)
            Text(Duration.seconds(ride.duration).formatted(.time(pattern: .hourMinute)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
