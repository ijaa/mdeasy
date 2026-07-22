import Foundation

final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let theme = "theme"
        static let lastOpenedPath = "lastOpenedPath"
        static let outlineOpen = "outlineOpen"
        static let fontSizeScale = "fontSizeScale"
        static let contentMaxWidth = "contentMaxWidth"
    }

    var theme: String {
        get { defaults.string(forKey: Key.theme) ?? "sepia" }
        set { defaults.set(newValue, forKey: Key.theme) }
    }

    var lastOpenedPath: String? {
        get { defaults.string(forKey: Key.lastOpenedPath) }
        set { defaults.set(newValue, forKey: Key.lastOpenedPath) }
    }

    var outlineOpen: Bool {
        get {
            if defaults.object(forKey: Key.outlineOpen) == nil { return true }
            return defaults.bool(forKey: Key.outlineOpen)
        }
        set { defaults.set(newValue, forKey: Key.outlineOpen) }
    }

    /// 字号缩放系数，默认 1.0，范围 0.85–2.0。屏幕阅读用；打印不沿用（@media print 固定）。
    var fontSizeScale: Double {
        get {
            let v = defaults.object(forKey: Key.fontSizeScale) as? Double ?? 1.0
            return min(max(v, 0.85), 2.0)
        }
        set { defaults.set(min(max(newValue, 0.85), 2.0), forKey: Key.fontSizeScale) }
    }

    /// 正文内容最大宽度（px），默认 672（= 42rem @ 16px），范围 600–1100。
    var contentMaxWidth: Int {
        get {
            let v = defaults.object(forKey: Key.contentMaxWidth) as? Int ?? 672
            return min(max(v, 600), 1100)
        }
        set { defaults.set(min(max(newValue, 600), 1100), forKey: Key.contentMaxWidth) }
    }

    func set(key: String, value: Any?) {
        switch key {
        case "theme":
            if let s = value as? String { theme = s }
        case "outlineOpen":
            if let b = value as? Bool { outlineOpen = b }
        case "lastOpenedPath":
            lastOpenedPath = value as? String
        case "fontSizeScale":
            // JS JSON 可能把整数化的 Double 传成 Int，统一转 Double。
            if let n = value as? Double { fontSizeScale = n }
            else if let n = value as? Int { fontSizeScale = Double(n) }
        case "contentMaxWidth":
            if let n = value as? Int { contentMaxWidth = n }
            else if let n = value as? Double { contentMaxWidth = Int(n) }
        default:
            break
        }
    }
}
