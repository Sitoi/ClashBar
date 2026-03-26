import Foundation

protocol ProxyRepository: Sendable {
    func switchProxy(group: String, target: String) async throws
    func measureGroupLatency(group: String, url: String, timeout: Int) async throws -> GroupDelayMeasurement
}
