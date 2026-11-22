import Cocoa
import Carbon

// MARK: - Menu bar detection

/// Each display's menu bar is a Window Server window at kCGMainMenuWindowLevel.
/// When the menu bar is hidden (fullscreen space or auto-hide) that window is
/// moved off the top of the screen and drops out of the on-screen window list.
/// Owner name, layer and bounds are readable without Screen Recording permission.
enum MenuBar {
    struct State { var visible: Bool; var height: CGFloat? }

    /// Menu bar heights only change with display configuration, so the full window list is read rarely.
    private static var heightCache: [CGRect]?
    static func invalidateHeights() { heightCache = nil }

    static func states(for screens: [NSScreen]) -> [NSScreen: State] {
        let level = Int(CGWindowLevelForKey(.mainMenuWindow))
        func bars(_ opt: CGWindowListOption) -> [CGRect] {
            let list = CGWindowListCopyWindowInfo(opt, kCGNullWindowID) as? [[String: Any]] ?? []
            return list.compactMap { w in
                guard (w[kCGWindowOwnerName as String] as? String) == "Window Server",
                      (w[kCGWindowLayer as String] as? Int) == level,
                      let b = w[kCGWindowBounds as String] as? NSDictionary,
                      let r = CGRect(dictionaryRepresentation: b), r.height < 80 else { return nil }
                return r
            }
        }
        let onScreen = bars([.optionOnScreenOnly])
        if heightCache == nil { heightCache = bars([.optionAll]) }
        let all = heightCache!
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0

        var out: [NSScreen: State] = [:]
        for s in screens {
            let cgTop = primaryHeight - s.frame.maxY            // screen's top edge, CG coordinates
            let sameColumn: (CGRect) -> Bool = { abs($0.minX - s.frame.minX) < 2 && abs($0.width - s.frame.width) < 2 }
            let height = all.first(where: sameColumn)?.height
            // Visible if any part of an on-screen menu bar reaches into this screen (includes the slide-in animation).
            let visible = onScreen.contains { sameColumn($0) && $0.maxY > cgTop + 1 && $0.minY < cgTop + s.frame.height }
            out[s] = State(visible: visible, height: height)
        }
        return out
    }
}

// MARK: - App icon follows light / dark appearance

/// The bundle's own icon (Hourglance.icns) is the light-mode one. In dark mode the app sets
/// HourglanceDark.icns as a custom Finder icon on its bundle; back in light mode it removes the
/// custom icon, which leaves the bundle untouched. (A native dark app icon needs an Icon Composer
/// file compiled by Xcode's actool; this keeps the build Command-Line-Tools-only.)
enum AppIcon {
    private static var lastDark: Bool?

    static func apply() {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        guard dark != lastDark else { return }
        lastDark = dark
        let bundle = Bundle.main.bundlePath
        guard bundle.hasSuffix(".app"), FileManager.default.isWritableFile(atPath: bundle) else { return }
        let icon = dark ? Bundle.main.url(forResource: "HourglanceDark", withExtension: "icns").flatMap(NSImage.init(contentsOf:)) : nil
        if dark && icon == nil { return }
        let hasCustom = FileManager.default.fileExists(atPath: bundle + "/Icon\r")
        if !dark && !hasCustom { return }                    // already the plain bundle icon
        NSWorkspace.shared.setIcon(icon, forFile: bundle, options: [])
        NSWorkspace.shared.noteFileSystemChanged(bundle)
    }
}

// MARK: - Global hotkey (Carbon; needs no Accessibility permission)

final class HotKey {
    static let shared = HotKey()
    var handler: (() -> Void)?
    private var ref: EventHotKeyRef?
    private var installed = false

    func register(keyCode: Int, modifiers: NSEvent.ModifierFlags) {
        unregister()
        if !installed {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async { HotKey.shared.handler?() }
                return noErr
            }, 1, &spec, nil, nil)
            installed = true
        }
        var mods: UInt32 = 0
        if modifiers.contains(.command) { mods |= UInt32(cmdKey) }
        if modifiers.contains(.option) { mods |= UInt32(optionKey) }
        if modifiers.contains(.control) { mods |= UInt32(controlKey) }
        if modifiers.contains(.shift) { mods |= UInt32(shiftKey) }
        let id = EventHotKeyID(signature: OSType(0x4847_4C43), id: 1)   // 'HGLC'
        RegisterEventHotKey(UInt32(keyCode), mods, id, GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let r = ref { UnregisterEventHotKey(r); ref = nil }
    }
}
