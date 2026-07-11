import Darwin
import Foundation

final class ConfigDirectoryMonitor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.clashbar.config-monitor", qos: .utility)
    private let onChange: @Sendable () -> Void
    private let directorySource: DispatchSourceFileSystemObject
    private var selectedFileSource: DispatchSourceFileSystemObject?

    init?(directoryURL: URL, selectedFileURL: URL?, onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
        guard let source = Self.makeSource(
            url: directoryURL,
            events: [.write, .delete, .extend, .attrib, .link, .rename, .revoke],
            queue: self.queue,
            onChange: onChange)
        else { return nil }

        self.directorySource = source
        self.updateSelectedFile(selectedFileURL)
    }

    func updateSelectedFile(_ fileURL: URL?) {
        self.selectedFileSource?.cancel()
        self.selectedFileSource = fileURL.flatMap {
            Self.makeSource(
                url: $0,
                events: [.write, .delete, .extend, .attrib, .rename, .revoke],
                queue: self.queue,
                onChange: self.onChange)
        }
    }

    func cancel() {
        self.directorySource.cancel()
        self.selectedFileSource?.cancel()
        self.selectedFileSource = nil
    }

    deinit {
        self.cancel()
    }

    private static func makeSource(
        url: URL,
        events: DispatchSource.FileSystemEvent,
        queue: DispatchQueue,
        onChange: @escaping @Sendable () -> Void) -> DispatchSourceFileSystemObject?
    {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: events,
            queue: queue)
        source.setEventHandler(handler: onChange)
        source.setCancelHandler { close(descriptor) }
        source.resume()
        return source
    }
}
