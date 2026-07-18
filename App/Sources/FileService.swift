import Foundation

struct MarkdownFile {
    let path: String
    let baseDir: String
    let text: String
    let encoding: String
    let mtimeMs: Double
}

enum FileServiceError: LocalizedError {
    case notFound(String)
    case unreadable(String)
    case notFile(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let p): return "File not found:\n\(p)"
        case .unreadable(let p): return "Cannot read file:\n\(p)"
        case .notFile(let p): return "Not a file:\n\(p)"
        }
    }
}

enum FileService {
    static func readMarkdown(path: String) throws -> MarkdownFile {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            throw FileServiceError.notFound(url.path)
        }
        guard !isDir.boolValue else {
            throw FileServiceError.notFile(url.path)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw FileServiceError.unreadable(url.path)
        }

        let (text, encodingName) = decode(data)
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0

        return MarkdownFile(
            path: url.path,
            baseDir: url.deletingLastPathComponent().path,
            text: text,
            encoding: encodingName,
            mtimeMs: mtime * 1000
        )
    }

    /// Resolve a relative asset path against baseDir; reject path escape.
    static func resolveAsset(baseDir: String, relative: String) -> URL? {
        let base = URL(fileURLWithPath: baseDir, isDirectory: true)
        guard let candidate = PathSandbox.join(base: base, relative: relative) else {
            return nil
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDir), !isDir.boolValue else {
            return nil
        }
        return candidate
    }

    /// 去除 `#fragment` 与 `?query` 后的纯路径部分，用于把文档内 .md 链接
    /// （如 `intro.md?x=1`、`intro.md#section`）归一成可被 `resolveAsset` 解析的相对路径。
    static func stripQueryAndFragment(_ href: String) -> String {
        var path = href
        if let q = path.firstIndex(of: "?") { path = String(path[..<q]) }
        if let f = path.firstIndex(of: "#") { path = String(path[..<f]) }
        return path
    }

    /// 统一的 Markdown 后缀集（drag&drop、导出去后缀名、md 链接校验共用，防漂移）。
    private static let markdownSuffixes: [String] = [
        ".md", ".markdown", ".mdx", ".mdown", ".mkd", ".mkdn", ".mdwn",
    ]

    /// 路径是否为受支持的 Markdown 文件名（大小写无关）。
    static func isMarkdownPath(_ path: String) -> Bool {
        let lower = path.lowercased()
        return markdownSuffixes.contains { lower.hasSuffix($0) }
    }

    private static func decode(_ data: Data) -> (String, String) {
        if let s = String(data: data, encoding: .utf8) {
            return (s, "utf-8")
        }
        if let s = String(data: data, encoding: .utf16) {
            return (s, "utf-16")
        }
        // Fallback: lossy ISO Latin-1 style
        let s = String(decoding: data, as: UTF8.self)
        return (s, "utf-8-lossy")
    }
}
