import AppKit
import WebKit

final class DropView: NSView {
    var onDropMarkdown: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        markdownPaths(from: sender).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let path = markdownPaths(from: sender).first else { return false }
        onDropMarkdown?(path)
        return true
    }

    private func markdownPaths(from sender: NSDraggingInfo) -> [String] {
        let pb = sender.draggingPasteboard
        guard let items = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else {
            return []
        }
        return items.map(\.path).filter { path in
            let lower = path.lowercased()
            return lower.hasSuffix(".md") || lower.hasSuffix(".markdown") || lower.hasSuffix(".mdx") || lower.hasSuffix(".mdown")
        }
    }
}

final class ReaderViewController: NSViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private var webView: WKWebView!
    private let assetHandler = AssetSchemeHandler()
    private let fileWatcher = FileWatcher()
    private var currentPath: String?
    private var readerReady = false
    private var pendingDoc: [String: Any]?

    override func loadView() {
        let drop = DropView(frame: NSRect(x: 0, y: 0, width: 960, height: 720))
        drop.onDropMarkdown = { [weak self] path in
            self?.openFile(path: path)
        }
        view = drop
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        loadReader()
        fileWatcher.onChange = { [weak self] path in
            DispatchQueue.main.async {
                self?.handleFileChanged(path: path)
            }
        }
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(assetHandler, forURLScheme: AssetSchemeHandler.scheme)
        config.userContentController.add(self, name: "mdeasy")
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let wv = WKWebView(frame: view.bounds, configuration: config)
        wv.autoresizingMask = [.width, .height]
        wv.navigationDelegate = self
        if #available(macOS 13.3, *) {
            wv.isInspectable = true
        }
        view.addSubview(wv)
        webView = wv
    }

    private func loadReader() {
        let candidates: [(String?, String)] = [
            ("reader", "index"),
            ("Resources/reader", "index"),
        ]
        var indexURL: URL?
        var access: URL?
        for (sub, name) in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "html", subdirectory: sub) {
                indexURL = url
                access = url.deletingLastPathComponent()
                break
            }
        }
        // Folder-reference fallback: …/Contents/Resources/Resources/reader/index.html
        if indexURL == nil, let resourceURL = Bundle.main.resourceURL {
            let nested = resourceURL.appendingPathComponent("Resources/reader/index.html")
            let flat = resourceURL.appendingPathComponent("reader/index.html")
            if FileManager.default.fileExists(atPath: flat.path) {
                indexURL = flat
                access = flat.deletingLastPathComponent()
            } else if FileManager.default.fileExists(atPath: nested.path) {
                indexURL = nested
                access = nested.deletingLastPathComponent()
            }
        }

        guard let indexURL, let access else {
            showFatal("reader/index.html missing from app bundle.\nRun: ./scripts/build-reader.sh && ./scripts/sync-reader-to-app.sh")
            return
        }
        webView.loadFileURL(indexURL, allowingReadAccessTo: access)
    }

    func openFile(path: String) {
        do {
            let payload = try FileService.readMarkdown(path: path)
            currentPath = payload.path
            Preferences.shared.lastOpenedPath = payload.path
            assetHandler.baseDir = URL(fileURLWithPath: payload.baseDir, isDirectory: true)
            fileWatcher.watch(path: payload.path)
            view.window?.title = URL(fileURLWithPath: payload.path).lastPathComponent
            let doc: [String: Any] = [
                "type": "doc",
                "path": payload.path,
                "baseDir": payload.baseDir,
                "text": payload.text,
                "encoding": payload.encoding,
                "mtimeMs": payload.mtimeMs
            ]
            if readerReady {
                sendBridgeEvent(doc)
            } else {
                pendingDoc = doc
            }
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func reloadCurrentFile() {
        guard let path = currentPath else { return }
        openFile(path: path)
    }

    func requestExportHTML() {
        sendBridgeEvent(["type": "request-export"])
    }

    func revealInFinder() {
        guard let path = currentPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func openInEditor() {
        guard let path = currentPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func setTheme(_ name: String) {
        Preferences.shared.theme = name
        sendBridgeEvent(["type": "theme", "name": name])
    }

    func sendBridgeEvent(_ object: [String: Any]) {
        guard
            let data = try? JSONSerialization.data(withJSONObject: object, options: []),
            let json = String(data: data, encoding: .utf8)
        else { return }
        let js = "window.__mdeasy && window.__mdeasy.handle(\(json));"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    private func handleFileChanged(path: String) {
        guard path == currentPath else { return }
        openFile(path: path)
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "mdeasy"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showFatal(_ message: String) {
        let label = NSTextField(wrappingLabelWithString: message)
        label.frame = view.bounds.insetBy(dx: 24, dy: 24)
        label.autoresizingMask = [.width, .height]
        view.addSubview(label)
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "mdeasy",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "ready":
            readerReady = true
            sendBridgeEvent([
                "type": "theme",
                "name": Preferences.shared.theme
            ])
            if let pendingDoc {
                sendBridgeEvent(pendingDoc)
                self.pendingDoc = nil
            }
        case "export-html":
            handleExport(body)
        case "open-in-editor":
            openInEditor()
        case "reveal-in-finder":
            revealInFinder()
        case "set-preference":
            if let key = body["key"] as? String {
                Preferences.shared.set(key: key, value: body["value"])
            }
        case "error":
            if let msg = body["message"] as? String {
                NSLog("reader error: %@", msg)
            }
        default:
            break
        }
    }

    private func handleExport(_ body: [String: Any]) {
        guard let html = body["html"] as? String else { return }
        let suggested = (body["suggestedName"] as? String) ?? "export.html"
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggested
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.html]
        } else {
            panel.allowedFileTypes = ["html"]
        }
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                try html.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}
