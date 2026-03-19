import Foundation

enum MachineConnectionStatus: Equatable {
    case unknown
    case checking
    case connected(version: String)
    case failed(reason: String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var shortLabel: String {
        switch self {
        case .unknown: "?"
        case .checking: "…"
        case let .connected(version): "✓ \(version)"
        case let .failed(reason): "✗ \(reason)"
        }
    }
}

@MainActor
final class RemoteMachineStore: ObservableObject {
    private static let storageKey = "clashbar.remote.machines"
    private static let activeTargetKey = "clashbar.remote.active_target_id"

    private let defaults: UserDefaults

    @Published var machines: [RemoteMachine] = []
    @Published var activeTargetID: UUID?
    @Published var machineStatuses: [UUID: MachineConnectionStatus] = [:]

    private var connectivityTimer: Task<Void, Never>?

    var activeTarget: MachineTarget {
        guard let id = activeTargetID,
              let machine = machines.first(where: { $0.id == id })
        else {
            return .local
        }
        return .remote(machine)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.machines = Self.loadMachines(from: defaults)
        self.activeTargetID = Self.loadActiveTargetID(from: defaults)
    }

    func addMachine(_ machine: RemoteMachine) {
        self.machines.append(machine)
        self.persist()
    }

    func updateMachine(_ machine: RemoteMachine) {
        guard let index = machines.firstIndex(where: { $0.id == machine.id }) else { return }
        self.machines[index] = machine
        self.persist()
    }

    func removeMachine(id: UUID) {
        self.machines.removeAll { $0.id == id }
        if self.activeTargetID == id {
            self.activeTargetID = nil
            self.persistActiveTarget()
        }
        self.persist()
    }

    func selectTarget(_ target: MachineTarget) {
        switch target {
        case .local:
            self.activeTargetID = nil
        case let .remote(machine):
            self.activeTargetID = machine.id
        }
        self.persistActiveTarget()
    }

    func resetActiveTarget() {
        self.activeTargetID = nil
        self.persistActiveTarget()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(machines) else { return }
        self.defaults.set(data, forKey: Self.storageKey)
    }

    private func persistActiveTarget() {
        if let id = activeTargetID {
            self.defaults.set(id.uuidString, forKey: Self.activeTargetKey)
        } else {
            self.defaults.removeObject(forKey: Self.activeTargetKey)
        }
    }

    private static func loadMachines(from defaults: UserDefaults) -> [RemoteMachine] {
        guard let data = defaults.data(forKey: storageKey),
              let machines = try? JSONDecoder().decode([RemoteMachine].self, from: data)
        else {
            return []
        }
        return machines
    }

    private static func loadActiveTargetID(from defaults: UserDefaults) -> UUID? {
        guard let string = defaults.string(forKey: activeTargetKey) else { return nil }
        return UUID(uuidString: string)
    }

    // MARK: - Connectivity Checking

    func statusFor(_ id: UUID) -> MachineConnectionStatus {
        self.machineStatuses[id] ?? .unknown
    }

    func checkAllConnectivity() {
        for machine in self.machines {
            self.checkConnectivity(for: machine)
        }
    }

    func checkConnectivity(for machine: RemoteMachine) {
        self.machineStatuses[machine.id] = .checking
        Task {
            let status = await Self.probe(machine: machine)
            self.machineStatuses[machine.id] = status
        }
    }

    func startPeriodicConnectivityChecks() {
        self.stopPeriodicConnectivityChecks()
        self.checkAllConnectivity()
        self.connectivityTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.checkAllConnectivity()
            }
        }
    }

    func stopPeriodicConnectivityChecks() {
        self.connectivityTimer?.cancel()
        self.connectivityTimer = nil
    }

    private static func probe(machine: RemoteMachine) async -> MachineConnectionStatus {
        let addr = machine.controllerAddress
        let base = addr.contains("://") ? addr : "http://\(addr)"
        guard let url = URL(string: "\(base)/version") else {
            return .failed(reason: "Invalid URL")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        if let secret = machine.secret, !secret.isEmpty {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        do {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 3
            config.timeoutIntervalForResource = 5
            let session = URLSession(configuration: config)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failed(reason: "No HTTP response")
            }
            if http.statusCode == 401 {
                return .failed(reason: "Auth failed (401)")
            }
            guard http.statusCode == 200 else {
                return .failed(reason: "HTTP \(http.statusCode)")
            }
            if let json = try? JSONDecoder().decode([String: String].self, from: data),
               let version = json["version"]
            {
                return .connected(version: version)
            }
            return .connected(version: "OK")
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                return .failed(reason: "Timeout")
            case .cannotConnectToHost:
                return .failed(reason: "Connection refused")
            case .networkConnectionLost:
                return .failed(reason: "Connection lost")
            default:
                return .failed(reason: error.localizedDescription)
            }
        } catch {
            return .failed(reason: error.localizedDescription)
        }
    }
}
