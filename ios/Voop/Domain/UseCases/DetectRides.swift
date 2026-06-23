import Foundation

enum DetectRides {
    static let gapThreshold: TimeInterval = 5 * 60
    static let minimumDistanceMeters: Double = 500

    static func detect(points: [DataPoint], anchor: GpsAnchor?) -> [Ride] {
        guard points.count >= 2, let anchor else { return [] }

        var segments: [[DataPoint]] = []
        var current: [DataPoint] = [points[0]]

        for point in points.dropFirst() {
            let prev = current.last!
            let gapMs = point.monotonicMs > prev.monotonicMs
                ? point.monotonicMs - prev.monotonicMs
                : 0
            let gapSeconds = Double(gapMs) / 1000.0
            if gapSeconds > gapThreshold {
                segments.append(current)
                current = [point]
            } else {
                current.append(point)
            }
        }
        segments.append(current)

        return segments.compactMap { segment in
            guard segment.count >= 2 else { return nil }
            let timestamped = segment.map { p in
                TimestampedPoint(
                    date: anchor.date(forMonotonicMs: p.monotonicMs),
                    coordinate: p.location.map { .init(latitude: $0.lat, longitude: $0.lon) },
                    cumulativeCrankRevs: p.cumulativeCrankRevs
                )
            }
            let distance = CalculateMetrics.totalDistance(points: timestamped)
            guard distance >= minimumDistanceMeters else { return nil }
            return Ride(
                id: UUID(),
                startDate: timestamped.first!.date,
                endDate: timestamped.last!.date,
                points: timestamped
            )
        }
    }
}
