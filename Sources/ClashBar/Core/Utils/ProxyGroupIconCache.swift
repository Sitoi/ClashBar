import AppKit
import SwiftUI

final class ProxyGroupIconCache: @unchecked Sendable {
    static var shared: ProxyGroupIconCache {
        guard let _shared else { fatalError("Call configure(iconDirectory:) before use") }
        return _shared
    }

    private nonisolated(unsafe) static var _shared: ProxyGroupIconCache?

    static func configure(iconDirectory: URL) {
        self._shared = ProxyGroupIconCache(iconDirectory: iconDirectory)
    }

    private let cache = NSCache<NSURL, NSImage>()
    private let diskDir: URL

    private init(iconDirectory: URL) {
        self.diskDir = iconDirectory
        try? FileManager.default.createDirectory(at: iconDirectory, withIntermediateDirectories: true)
    }

    func image(for url: URL) async -> NSImage? {
        let cacheKey = url as NSURL
        if let img = self.cache.object(forKey: cacheKey) { return img }

        let path = self.diskDir.appendingPathComponent(url.cacheKey)
        if let data = try? Data(contentsOf: path), let img = NSImage(data: data) {
            self.cache.setObject(img, forKey: cacheKey)
            return img
        }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img = NSImage(data: data)
        else { return nil }
        self.cache.setObject(img, forKey: cacheKey)
        try? data.write(to: path)
        return img
    }
}

extension URL {
    fileprivate var cacheKey: String {
        self.absoluteString.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
    }
}

struct ProxyGroupIconView: View {
    let url: URL
    @State private var nsImage: NSImage?

    var body: some View {
        ZStack {
            if let nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .task(id: self.url) {
            self.nsImage = await ProxyGroupIconCache.shared.image(for: self.url)
        }
    }
}
