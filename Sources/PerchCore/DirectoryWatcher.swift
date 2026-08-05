import Foundation

/// Watches a directory for changes and calls `onChange` (debounced) on the main
/// queue. A DispatchSource vnode monitor catches in-place writes; a 2 s poll
/// timer covers atomic `mv` that swaps the directory entry's inode.
public final class DirectoryWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let fd: Int32
    private let onChange: () -> Void
    private var debounce: DispatchWorkItem?
    private let pollTimer: DispatchSourceTimer

    public init(url: URL, onChange: @escaping () -> Void) {
        self.onChange = onChange
        self.fd = open(url.path, O_EVTONLY)
        self.source = nil
        self.pollTimer = DispatchSource.makeTimerSource(queue: .main)
        // All stored properties are now initialized; safe to capture self below.
        if fd >= 0 {
            let s = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: [.write, .extend, .link], queue: .main)
            s.setEventHandler { [weak self] in self?.fire() }
            let capturedFd = fd
            s.setCancelHandler { close(capturedFd) }
            s.resume()
            source = s
        }
        pollTimer.schedule(deadline: .now() + 2, repeating: 2)
        pollTimer.setEventHandler { [weak self] in self?.onChange() }
        pollTimer.resume()
    }

    private func fire() {
        debounce?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.onChange() }
        debounce = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: w)
    }

    deinit {
        source?.cancel()
        pollTimer.cancel()
    }
}
