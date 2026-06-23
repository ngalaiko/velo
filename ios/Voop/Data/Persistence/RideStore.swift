import CoreLocation
import Foundation
import SwiftData

@Model
final class RideRecord {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var pointsData: Data

    init(id: UUID, startDate: Date, endDate: Date, pointsData: Data) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.pointsData = pointsData
    }
}

@MainActor
final class RideStore: RideRepository {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(for: RideRecord.self)
    }

    func save(_ ride: Ride) async throws {
        let data = try JSONEncoder().encode(ride.points.map { SerializedPoint($0) })
        let record = RideRecord(id: ride.id, startDate: ride.startDate, endDate: ride.endDate, pointsData: data)
        container.mainContext.insert(record)
        try container.mainContext.save()
    }

    func fetchAll() async throws -> [Ride] {
        let descriptor = FetchDescriptor<RideRecord>(sortBy: [SortDescriptor(\.startDate)])
        let records = try container.mainContext.fetch(descriptor)
        return records.compactMap { Ride(from: $0) }
    }

    func delete(id: UUID) async throws {
        let predicate = #Predicate<RideRecord> { $0.id == id }
        let records = try container.mainContext.fetch(FetchDescriptor(predicate: predicate))
        records.forEach { container.mainContext.delete($0) }
        try container.mainContext.save()
    }
}

private struct SerializedPoint: Codable {
    let date: Date
    let lat: Double?
    let lon: Double?
    let cumulativeCrankRevs: UInt16

    init(_ p: TimestampedPoint) {
        date = p.date
        lat = p.coordinate?.latitude
        lon = p.coordinate?.longitude
        cumulativeCrankRevs = p.cumulativeCrankRevs
    }
}

private extension Ride {
    init?(from record: RideRecord) {
        guard let points = try? JSONDecoder().decode([SerializedPoint].self, from: record.pointsData)
        else { return nil }
        self.init(
            id: record.id,
            startDate: record.startDate,
            endDate: record.endDate,
            points: points.map { sp in
                TimestampedPoint(
                    date: sp.date,
                    coordinate: sp.lat.flatMap { lat in
                        sp.lon.map { lon in CLLocationCoordinate2D(latitude: lat, longitude: lon) }
                    },
                    cumulativeCrankRevs: sp.cumulativeCrankRevs
                )
            }
        )
    }
}
