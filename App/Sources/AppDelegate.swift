import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?
    private var pendingPaths: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let wc = MainWindowController()
        windowController = wc
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)

        if !pendingPaths.isEmpty {
            for path in pendingPaths {
                wc.openFile(path: path)
            }
            pendingPaths.removeAll()
        } else if let last = Preferences.shared.lastOpenedPath, FileManager.default.fileExists(atPath: last) {
            wc.openFile(path: last)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let paths = urls.map(\.path)
        if let wc = windowController {
            for path in paths {
                wc.openFile(path: path)
            }
        } else {
            pendingPaths.append(contentsOf: paths)
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if let wc = windowController {
            wc.openFile(path: filename)
        } else {
            pendingPaths.append(filename)
        }
        return true
    }
}
