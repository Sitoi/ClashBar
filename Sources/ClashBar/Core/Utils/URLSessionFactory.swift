import Foundation

enum URLSessionFactory {
    struct SessionOptions {
        var timeoutIntervalForRequest: TimeInterval
        var timeoutIntervalForResource: TimeInterval
        var httpMaximumConnectionsPerHost: Int?
        var waitsForConnectivity: Bool
        var requestCachePolicy: URLRequest.CachePolicy

        init(
            timeoutIntervalForRequest: TimeInterval,
            timeoutIntervalForResource: TimeInterval,
            httpMaximumConnectionsPerHost: Int? = nil,
            waitsForConnectivity: Bool = false,
            requestCachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData)
        {
            self.timeoutIntervalForRequest = timeoutIntervalForRequest
            self.timeoutIntervalForResource = timeoutIntervalForResource
            self.httpMaximumConnectionsPerHost = httpMaximumConnectionsPerHost
            self.waitsForConnectivity = waitsForConnectivity
            self.requestCachePolicy = requestCachePolicy
        }
    }

    static func makeEphemeralSession(options: SessionOptions) -> URLSession {
        URLSession(configuration: self.makeEphemeralConfiguration(options: options))
    }

    static func makeEphemeralConfiguration(options: SessionOptions) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = options.timeoutIntervalForRequest
        config.timeoutIntervalForResource = options.timeoutIntervalForResource
        config.waitsForConnectivity = options.waitsForConnectivity
        config.requestCachePolicy = options.requestCachePolicy
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        if let perHost = options.httpMaximumConnectionsPerHost {
            config.httpMaximumConnectionsPerHost = perHost
        }
        return config
    }
}
