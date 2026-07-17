import AppKit
import UniformTypeIdentifiers

final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let contentController = ReaderViewController()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "mdeasy"
        window.minSize = NSSize(width: 480, height: 360)
        window.center()
        window.titlebarAppearsTransparent = true
        window.setFrameAutosaveName("MainWindow")

        self.init(window: window)
        window.delegate = self
        window.contentViewController = contentController
        setupMenu()
    }

    func openFile(path: String) {
        contentController.openFile(path: path)
    }

    private func setupMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About mdeasy", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit mdeasy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "Open…", action: #selector(openMarkdown(_:)), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Reload", action: #selector(reloadMarkdown(_:)), keyEquivalent: "r")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Export HTML…", action: #selector(exportHTML(_:)), keyEquivalent: "e")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Reveal in Finder", action: #selector(revealInFinder(_:)), keyEquivalent: "R")
        fileMenu.addItem(withTitle: "Open in Editor", action: #selector(openInEditor(_:)), keyEquivalent: "E")

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(withTitle: "Toggle Outline", action: #selector(toggleOutline(_:)), keyEquivalent: "b")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Theme: Light", action: #selector(setThemeLight(_:)), keyEquivalent: "1")
        viewMenu.addItem(withTitle: "Theme: Dark", action: #selector(setThemeDark(_:)), keyEquivalent: "2")
        viewMenu.addItem(withTitle: "Theme: Sepia", action: #selector(setThemeSepia(_:)), keyEquivalent: "3")
        viewMenu.addItem(withTitle: "Theme: Green", action: #selector(setThemeGreen(_:)), keyEquivalent: "4")

        NSApp.mainMenu = mainMenu
    }

    @objc private func openMarkdown(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [
                UTType(filenameExtension: "md") ?? .plainText,
                UTType(filenameExtension: "markdown") ?? .plainText,
                UTType(filenameExtension: "mdx") ?? .plainText,
                .plainText
            ]
        }
        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            self?.openFile(path: url.path)
        }
    }

    @objc private func reloadMarkdown(_ sender: Any?) {
        contentController.reloadCurrentFile()
    }

    @objc private func exportHTML(_ sender: Any?) {
        contentController.requestExportHTML()
    }

    @objc private func revealInFinder(_ sender: Any?) {
        contentController.revealInFinder()
    }

    @objc private func openInEditor(_ sender: Any?) {
        contentController.openInEditor()
    }

    @objc private func toggleOutline(_ sender: Any?) {
        contentController.sendBridgeEvent(["type": "toggle-outline"])
    }

    @objc private func setThemeLight(_ sender: Any?) { contentController.setTheme("light") }
    @objc private func setThemeDark(_ sender: Any?) { contentController.setTheme("dark") }
    @objc private func setThemeSepia(_ sender: Any?) { contentController.setTheme("sepia") }
    @objc private func setThemeGreen(_ sender: Any?) { contentController.setTheme("green") }

    @objc private func showAbout() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let alert = NSAlert()
        alert.messageText = "mdeasy"
        alert.informativeText = """
        Version \(version)

        A tiny offline Markdown reader for macOS.
        No account. No network. Focus on reading.

        Unsigned self-use build: System Settings → Privacy & Security → Open Anyway
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
