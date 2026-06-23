import CoreLocation
import Foundation

struct Ride: Identifiable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let points: [TimestampedPoint]

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    static func == (lhs: Ride, rhs: Ride) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct TimestampedPoint {
    let date: Date
    let coordinate: CLLocationCoordinate2D?
    let cumulativeCrankRevs: UInt16
}
