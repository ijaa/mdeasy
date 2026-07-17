import Foundation

final class FileWatcher {
    var onChange: ((String) -> Void)?

    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private var watchedPath: String?
    private let queue = DispatchQueue(label: "app.mdeasy.filewatcher")
    private var debounceWork: DispatchWorkItem?

    func watch(path: String) {
        stop()
        watchedPath = path
        fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .rename, .delete],
            queue: queue
        )
        src.setEventHandler { [weak self] in
            self?.scheduleNotify()
        }
        src.setCancelHandler { [weak self] in
            if let self, self.fd >= 0 {
                close(self.fd)
                self.fd = -1
            }
        }
        source = src
        src.resume()
    }

    func stop() {
        debounceWork?.cancel()
        debounceWork = nil
        source?.cancel()
        source = nil
        watchedPath = nil
    }

    private func scheduleNotify() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let path = self.watchedPath else { return }
            // Re-arm after rename/replace (common for atomic saves)
            if !FileManager.default.fileExists(atPath: path) {
                return
            }
            self.watch(path: path)
            self.onChange?(path)
        }
        debounceWork = work
        queue.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    deinit {
        stop()
    }
}
