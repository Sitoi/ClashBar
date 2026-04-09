import Foundation

enum AppReleaseServiceError: Error {
    case invalidResponse
    case statusCode(Int)
}

enum AppReleaseService {
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/Sitoi/ClashBar/releases/latest")!

    static func fetchLatestRelease(currentVersion: String) async throws -> AppReleaseInfo {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.timeoutInterval = 8
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("ClashBar/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let session = Self.makeSession()
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppReleaseServiceError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw AppReleaseServiceError.statusCode(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(AppReleaseInfo.self, from: data)
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 15
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        return URLSession(configuration: configuration)
    }
}
