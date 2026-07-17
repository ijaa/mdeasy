import Foundation

final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let theme = "theme"
        static let lastOpenedPath = "lastOpenedPath"
        static let outlineOpen = "outlineOpen"
    }

    var theme: String {
        get { defaults.string(forKey: Key.theme) ?? "light" }
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

    func set(key: String, value: Any?) {
        switch key {
        case "theme":
            if let s = value as? String { theme = s }
        case "outlineOpen":
            if let b = value as? Bool { outlineOpen = b }
        case "lastOpenedPath":
            lastOpenedPath = value as? String
        default:
            break
        }
    }
}
