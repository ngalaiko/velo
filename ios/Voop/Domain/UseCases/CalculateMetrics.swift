import CoreLocation
import Foundation

struct RideMetrics {
    let totalDistanceMeters: Double
    let durationSeconds: TimeInterval
    let averageSpeedKph: Double
    let maxSpeedKph: Double
    let averageCadenceRpm: Double
    let maxCadenceRpm: Double
}

enum CalculateMetrics {
    /// Gear ratio × wheel circumference in meters, used to convert crank revs to distance.
    /// Defaults: 46/16 chainring, 700×25c wheel (2.105 m circumference).
    struct Config {
        var gearRatio: Double = 46.0 / 16.0
        var wheelCircumferenceMeters: Double = 2.105
    }

    static func totalDistance(points: [TimestampedPoint]) -> Double {
        var total = 0.0
        for i in 1 ..< points.count {
            guard
                let c1 = points[i - 1].coordinate,
                let c2 = points[i].coordinate
            else { continue }
            let loc1 = CLLocation(latitude: c1.latitude, longitude: c1.longitude)
            let loc2 = CLLocation(latitude: c2.latitude, longitude: c2.longitude)
            total += loc1.distance(from: loc2)
        }
        return total
    }

    static func compute(ride: Ride, config: Config = .init()) -> RideMetrics {
        let points = ride.points
        let distance = totalDistance(points: points)
        let duration = ride.duration

        var speedsSamples: [Double] = []
        var cadenceSamples: [Double] = []

        for i in 1 ..< points.count {
            let dt = points[i].date.timeIntervalSince(points[i - 1].date)
            guard dt > 0 else { continue }

            let revDelta = Int32(points[i].cumulativeCrankRevs) - Int32(points[i - 1].cumulativeCrankRevs)
            if revDelta > 0 {
                let cadenceRpm = Double(revDelta) / dt * 60.0
                cadenceSamples.append(cadenceRpm)

                let distanceM = Double(revDelta) * config.gearRatio * config.wheelCircumferenceMeters
                let speedKph = (distanceM / dt) * 3.6
                speedsSamples.append(speedKph)
            }
        }

        return RideMetrics(
            totalDistanceMeters: distance,
            durationSeconds: duration,
            averageSpeedKph: speedsSamples.isEmpty ? 0 : speedsSamples.reduce(0, +) / Double(speedsSamples.count),
            maxSpeedKph: speedsSamples.max() ?? 0,
            averageCadenceRpm: cadenceSamples.isEmpty ? 0 : cadenceSamples.reduce(0, +) / Double(cadenceSamples.count),
            maxCadenceRpm: cadenceSamples.max() ?? 0
        )
    }
}
