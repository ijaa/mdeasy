import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?
    private var pendingPaths: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure we are a normal foreground app with Dock icon + menu bar.
        NSApp.setActivationPolicy(.regular)

        let wc = MainWindowController()
        windowController = wc
        wc.showWindow(nil)

        // Force key/front in case autosaved frame was off-screen or order was wrong.
        if let window = wc.window {
            window.makeKeyAndOrderFront(nil)
            // If frame is off any screen, re-center.
            if NSScreen.screens.allSatisfy({ !$0.visibleFrame.intersects(window.frame) }) {
                window.center()
                window.makeKeyAndOrderFront(nil)
            }
        }

        NSApp.activate(ignoringOtherApps: true)

        if !pendingPaths.isEmpty {
            for path in pendingPaths {
                wc.openFile(path: path)
            }
            pendingPaths.removeAll()
        }
        // Do not auto-open last file on cold start — keeps first launch predictable.
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

    func application(_ application: NSApplication, open urls: [URL]) {
        let paths = urls.map(\.path)
        if let wc = windowController {
            for path in paths {
                wc.openFile(path: path)
            }
            wc.showWindow(nil)
            wc.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            pendingPaths.append(contentsOf: paths)
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if let wc = windowController {
            wc.openFile(path: filename)
            wc.showWindow(nil)
            wc.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            pendingPaths.append(filename)
        }
        return true
    }
}
