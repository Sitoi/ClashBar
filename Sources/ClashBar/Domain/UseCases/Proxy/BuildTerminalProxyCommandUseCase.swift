import Foundation

struct BuildTerminalProxyCommandUseCase {
    func execute(host: String = "127.0.0.1", httpPort: Int, socksPort: Int) -> String {
        "export https_proxy=http://\(host):\(httpPort) " +
            "http_proxy=http://\(host):\(httpPort) " +
            "all_proxy=socks5://\(host):\(socksPort)"
    }
}
