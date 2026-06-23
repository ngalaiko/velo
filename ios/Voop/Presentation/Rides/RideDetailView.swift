import MapKit
import SwiftUI

struct RideDetailView: View {
    let ride: Ride
    private var metrics: RideMetrics {
        CalculateMetrics.compute(ride: ride)
    }

    var body: some View {
        List {
            Section {
                Map {
                    MapPolyline(coordinates: ride.points.compactMap {
                        $0.coordinate.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                    })
                    .stroke(.blue, lineWidth: 3)
                }
                .frame(height: 260)
                .listRowInsets(EdgeInsets())
            }

            Section("Summary") {
                LabeledContent("Duration") {
                    Text(Duration.seconds(ride.duration).formatted(.time(pattern: .hourMinute)))
                }
                LabeledContent("Distance") {
                    Text(Measurement(value: metrics.totalDistanceMeters, unit: UnitLength.meters)
                        .formatted(.measurement(width: .abbreviated, usage: .road)))
                }
                LabeledContent("Avg Speed", value: "\(Int(metrics.averageSpeedKph)) km/h")
                LabeledContent("Max Speed", value: "\(Int(metrics.maxSpeedKph)) km/h")
                LabeledContent("Avg Cadence", value: "\(Int(metrics.averageCadenceRpm)) rpm")
                LabeledContent("Max Cadence", value: "\(Int(metrics.maxCadenceRpm)) rpm")
            }
        }
        .navigationTitle(ride.startDate.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
}
