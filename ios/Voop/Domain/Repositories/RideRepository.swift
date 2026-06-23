import Foundation

protocol RideRepository: Sendable {
    func save(_ ride: Ride) async throws
    func fetchAll() async throws -> [Ride]
    func delete(id: UUID) async throws
}
