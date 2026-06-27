import AppKit
import os
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

    private let storage = OSAllocatedUnfairLock<[URL: NSImage]>(initialState: [:])
    private let diskDir: URL

    private init(iconDirectory: URL) {
        self.diskDir = iconDirectory
        try? FileManager.default.createDirectory(at: iconDirectory, withIntermediateDirectories: true)
    }

    func cachedImage(for url: URL) -> NSImage? {
        self.storage.withLock { $0[url] }
    }

    func image(for url: URL) async -> NSImage? {
        if let img = self.storage.withLock({ $0[url] }) { return img }

        let path = self.diskDir.appendingPathComponent(url.cacheKey)
        if let data = try? Data(contentsOf: path), let img = NSImage(data: data) {
            self.storage.withLock { $0[url] = img }
            return img
        }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img = NSImage(data: data)
        else { return nil }
        self.storage.withLock { $0[url] = img }
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
            if let cached = ProxyGroupIconCache.shared.cachedImage(for: url) {
                self.nsImage = cached
                return
            }
            self.nsImage = await ProxyGroupIconCache.shared.image(for: self.url)
        }
    }
}
