import CoreLocation
import Foundation
import HealthKit

@MainActor
final class HealthKitService {
    private let store = HKHealthStore()

    func requestAuthorization() async throws {
        let typesToShare: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKQuantityType(.cyclingCadence),
            HKQuantityType(.distanceCycling),
        ]
        try await store.requestAuthorization(toShare: typesToShare, read: [])
    }

    func save(ride: Ride, metrics: RideMetrics, config: CalculateMetrics.Config = .init()) async throws {
        let workout = HKWorkout(
            activityType: .cycling,
            start: ride.startDate,
            end: ride.endDate,
            duration: ride.duration,
            totalEnergyBurned: nil,
            totalDistance: HKQuantity(unit: .meter(), doubleValue: metrics.totalDistanceMeters),
            metadata: nil
        )
        try await store.save(workout)
        try await saveRoute(ride: ride, workout: workout)
        try await saveCadence(ride: ride, workout: workout, config: config)
    }

    private func saveRoute(ride: Ride, workout: HKWorkout) async throws {
        let locations = ride.points.compactMap { point -> CLLocation? in
            guard let coord = point.coordinate else { return nil }
            return CLLocation(
                coordinate: coord,
                altitude: 0,
                horizontalAccuracy: 5,
                verticalAccuracy: -1,
                timestamp: point.date
            )
        }
        guard !locations.isEmpty else { return }

        let builder = HKWorkoutRouteBuilder(healthStore: store, device: nil)
        try await builder.insertRouteData(locations)
        try await builder.finishRoute(with: workout, metadata: nil)
    }

    private func saveCadence(ride: Ride, workout _: HKWorkout, config _: CalculateMetrics.Config) async throws {
        var samples: [HKQuantitySample] = []
        let points = ride.points
        for i in 1 ..< points.count {
            let dt = points[i].date.timeIntervalSince(points[i - 1].date)
            guard dt > 0 else { continue }
            let revDelta = Int32(points[i].cumulativeCrankRevs) - Int32(points[i - 1].cumulativeCrankRevs)
            guard revDelta > 0 else { continue }
            let cadenceRpm = Double(revDelta) / dt * 60.0
            let sample = HKQuantitySample(
                type: HKQuantityType(.cyclingCadence),
                quantity: HKQuantity(unit: .init(from: "count/min"), doubleValue: cadenceRpm),
                start: points[i - 1].date,
                end: points[i].date
            )
            samples.append(sample)
        }
        if !samples.isEmpty {
            try await store.save(samples)
        }
    }
}
