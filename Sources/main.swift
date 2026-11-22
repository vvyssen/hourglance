// Hourglance · 一瞥 — a tiny clock that sits in a screen corner when the menu bar is hidden
// (fullscreen apps, or "Automatically hide and show the menu bar").
// AppKit + SwiftUI, no dependencies. Build with ./build.sh (Command Line Tools only).

import Cocoa

Prefs.registerDefaults()
let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.setActivationPolicy(.accessory)   // no Dock icon
app.run()
