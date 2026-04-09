import Foundation

struct ResolveSystemProxyPortsUseCase {
    func execute(mixedPort: Int?, httpPort: Int?, socksPort: Int?) -> SystemProxyPorts {
        if let mixed = self.normalizedPort(mixedPort) {
            return SystemProxyPorts(httpPort: mixed, httpsPort: mixed, socksPort: mixed)
        }

        let resolvedHTTPPort = self.normalizedPort(httpPort)
        return SystemProxyPorts(
            httpPort: resolvedHTTPPort,
            httpsPort: resolvedHTTPPort,
            socksPort: self.normalizedPort(socksPort))
    }

    private func normalizedPort(_ value: Int?) -> Int? {
        guard let value, (1...65535).contains(value) else {
            return nil
        }
        return value
    }
}
