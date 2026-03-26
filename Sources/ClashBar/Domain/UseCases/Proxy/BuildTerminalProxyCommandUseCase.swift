import Foundation

struct BuildTerminalProxyCommandUseCase {
    func execute(host: String = "127.0.0.1", httpPort: Int, socksPort: Int) -> String {
        let formattedHost = self.formattedHostForProxyURL(host)
        return "export https_proxy=http://\(formattedHost):\(httpPort) " +
            "http_proxy=http://\(formattedHost):\(httpPort) " +
            "all_proxy=socks5://\(formattedHost):\(socksPort)"
    }

    private func formattedHostForProxyURL(_ host: String) -> String {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHost.contains(":"), !trimmedHost.hasPrefix("[") {
            return "[\(trimmedHost)]"
        }
        return trimmedHost
    }
}
