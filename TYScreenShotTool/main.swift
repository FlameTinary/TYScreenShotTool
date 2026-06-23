import AppKit

// Nib-less AppKit entry point.
// Top-level code in main.swift runs on the main thread at
// process start, but is not @MainActor-isolated. Since
// NSApplicationDelegate is @MainActor in Swift 6, we wrap
// delegate setup with assumeIsolated (safe at startup).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
