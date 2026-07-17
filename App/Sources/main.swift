import AppKit

// Programmatic AppKit entry (no storyboard / no @main on the delegate).
// Guarantees: shared NSApplication, regular activation policy, and a running event loop.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
