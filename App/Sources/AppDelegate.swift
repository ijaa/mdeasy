import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?
    private var pendingPaths: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let wc = MainWindowController()
        windowController = wc
        wc.showWindow(nil)

        if let window = wc.window {
            window.makeKeyAndOrderFront(nil)
            if NSScreen.screens.allSatisfy({ !$0.visibleFrame.intersects(window.frame) }) {
                window.center()
                window.makeKeyAndOrderFront(nil)
            }
        }

        NSApp.activate(ignoringOtherApps: true)

        // Files may arrive via Apple Events before or after this callback.
        flushPendingPaths()

        // Some Launch Services paths only show up slightly after launch.
        DispatchQueue.main.async { [weak self] in
            self?.flushPendingPaths()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            windowController?.showWindow(nil)
            windowController?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }

    // Modern Finder double-click / `open -a` path (macOS 10.13+).
    func application(_ application: NSApplication, open urls: [URL]) {
        enqueue(paths: urls.map { $0.standardizedFileURL.path })
    }

    // Legacy path still used by some system versions / tools.
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        enqueue(paths: [filename])
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        enqueue(paths: filenames)
        // Required when implementing openFiles: tell AppKit we handled them.
        sender.reply(toOpenOrPrint: .success)
    }

    private func enqueue(paths: [String]) {
        let cleaned = paths
            .map { ($0 as NSString).expandingTildeInPath }
            .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
            .filter { !$0.isEmpty }

        guard !cleaned.isEmpty else { return }

        if let wc = windowController {
            for path in cleaned {
                NSLog("mdeasy: open request → %@", path)
                wc.openFile(path: path)
            }
            wc.showWindow(nil)
            wc.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            pendingPaths.append(contentsOf: cleaned)
            NSLog("mdeasy: queued %d path(s) before window ready", cleaned.count)
        }
    }

    private func flushPendingPaths() {
        guard let wc = windowController, !pendingPaths.isEmpty else { return }
        let paths = pendingPaths
        pendingPaths.removeAll()
        for path in paths {
            NSLog("mdeasy: flush queued → %@", path)
            wc.openFile(path: path)
        }
        wc.showWindow(nil)
        wc.window?.makeKeyAndOrderFront(nil)
    }
}
