// Hourglance — a tiny clock that sits in a screen corner when the menu bar is hidden
// (fullscreen apps, or "Automatically hide and show the menu bar").
// Single file, AppKit only. Build with ./build.sh.

import Cocoa
import ServiceManagement

// MARK: - Settings

enum Corner: String, CaseIterable {
    case topRight, topLeft, bottomRight, bottomLeft
    var title: String {
        switch self {
        case .topRight: return "Top right"
        case .topLeft: return "Top left"
        case .bottomRight: return "Bottom right"
        case .bottomLeft: return "Bottom left"
        }
    }
    var isTop: Bool { self == .topRight || self == .topLeft }
    var isRight: Bool { self == .topRight || self == .bottomRight }
}

enum ShowMode: String, CaseIterable {
    case menuBarHidden, always
    var title: String { self == .always ? "Always" : "Only when menu bar is hidden" }
}

enum FontSize: String, CaseIterable {
    case small, medium, large
    var points: CGFloat { switch self { case .small: return 11; case .medium: return 13; case .large: return 16 } }
    var title: String { rawValue.capitalized }
}

final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard
    var onChange: (() -> Void)?

    private func get<T: RawRepresentable>(_ key: String, _ def: T) -> T where T.RawValue == String {
        d.string(forKey: key).flatMap(T.init(rawValue:)) ?? def
    }
    private func bool(_ key: String, _ def: Bool) -> Bool { d.object(forKey: key) == nil ? def : d.bool(forKey: key) }
    private func set(_ v: Any?, _ key: String) { d.set(v, forKey: key); onChange?() }

    var corner: Corner { get { get("corner", Corner.topRight) } set { set(newValue.rawValue, "corner") } }
    var showMode: ShowMode { get { get("showMode", ShowMode.menuBarHidden) } set { set(newValue.rawValue, "showMode") } }
    var fontSize: FontSize { get { get("fontSize", FontSize.medium) } set { set(newValue.rawValue, "fontSize") } }
    var showSeconds: Bool { get { bool("showSeconds", false) } set { set(newValue, "showSeconds") } }
    var showDate: Bool { get { bool("showDate", false) } set { set(newValue, "showDate") } }
    var use24h: Bool { get { bool("use24h", true) } set { set(newValue, "use24h") } }
    var background: Bool { get { bool("background", true) } set { set(newValue, "background") } }
    var fadeOnHover: Bool { get { bool("fadeOnHover", true) } set { set(newValue, "fadeOnHover") } }
    /// Display names the user turned off.
    var disabledScreens: Set<String> {
        get { Set(d.stringArray(forKey: "disabledScreens") ?? []) }
        set { set(Array(newValue), "disabledScreens") }
    }
}

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

// MARK: - Clock window

final class ClockPanel: NSPanel {
    let label = NSTextField(labelWithString: "")
    let box = NSView()

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true              // click-through: never steals clicks from the app below
        level = .statusBar                     // above fullscreen windows and the menu bar strip
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        animationBehavior = .none

        box.wantsLayer = true
        box.layer?.cornerRadius = 6
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byClipping
        box.addSubview(label)
        contentView = box
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private var lastKey = ""
    func layout(text: String, on screen: NSScreen, menuBarHeight: CGFloat, settingsVersion: Int) {
        let key = "\(text)|\(screen.frame)|\(menuBarHeight)|\(settingsVersion)"
        guard key != lastKey else { return }
        lastKey = key
        let st = Settings.shared
        label.font = .monospacedDigitSystemFont(ofSize: st.fontSize.points, weight: .medium)
        label.stringValue = text
        box.layer?.backgroundColor = st.background ? NSColor.black.withAlphaComponent(0.6).cgColor : nil
        label.shadow = st.background ? nil : {
            let s = NSShadow(); s.shadowColor = .black; s.shadowBlurRadius = 2; s.shadowOffset = .zero; return s
        }()

        let textSize = label.intrinsicContentSize
        let padX: CGFloat = 8, margin: CGFloat = 6
        let w = ceil(textSize.width + padX * 2)
        let h = ceil(min(max(textSize.height + 4, 18), max(menuBarHeight - 4, textSize.height + 2)))
        let f = screen.frame
        let x = st.corner.isRight ? f.maxX - w - margin : f.minX + margin
        // Top corners: centred in the menu bar strip (next to the notch on MacBooks). Bottom: just above the edge.
        let y = st.corner.isTop ? f.maxY - (menuBarHeight + h) / 2 : f.minY + margin
        setFrame(NSRect(x: x, y: y, width: w, height: h), display: false)
        box.frame = NSRect(x: 0, y: 0, width: w, height: h)
        label.frame = NSRect(x: 0, y: (h - textSize.height) / 2, width: w, height: textSize.height)
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

// MARK: - Controller

final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var panels: [NSScreen: ClockPanel] = [:]
    var statusItem: NSStatusItem!
    let formatter = DateFormatter()
    var tickTimer: Timer?
    var pollTimer: Timer?
    var mouseMonitor: Any?
    var settingsVersion = 0
    var appearanceObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Hourglance")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        Settings.shared.onChange = { [weak self] in
            self?.settingsVersion += 1; self?.configureFormatter(); self?.refresh()
        }
        configureFormatter()

        let nc = NotificationCenter.default, wnc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        wnc.addObserver(self, selector: #selector(refresh), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        wnc.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        wnc.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didWakeNotification, object: nil)

        // Menu bar can slide in/out at any time (auto-hide); poll cheaply.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.refresh() }
        pollTimer?.tolerance = 0.05
        scheduleTick()

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.updateHoverFade()
        }
        refresh()

        AppIcon.apply()
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { _, _ in
            DispatchQueue.main.async { AppIcon.apply() }
        }
    }

    // Fire exactly on each second boundary so the seconds digit is never late.
    func scheduleTick() {
        let now = Date().timeIntervalSince1970
        let next = Date(timeIntervalSince1970: floor(now) + 1.0005)
        tickTimer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            self?.refresh(); self?.scheduleTick()
        }
        RunLoop.main.add(tickTimer!, forMode: .common)
    }

    func configureFormatter() {
        let st = Settings.shared
        var tpl = st.use24h ? "HHmm" : "hmma"
        if st.showSeconds { tpl += "ss" }
        if st.showDate { tpl = "MMMdEEE" + tpl }
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate(tpl)
    }

    @objc func screensChanged() { MenuBar.invalidateHeights(); refresh() }

    @objc func refresh() {
        let st = Settings.shared
        let screens = NSScreen.screens
        let states = MenuBar.states(for: screens)
        let text = formatter.string(from: Date())

        for (screen, panel) in panels where !screens.contains(screen) {
            panel.orderOut(nil); panels[screen] = nil
        }
        for screen in screens {
            let state = states[screen] ?? .init(visible: false, height: nil)
            let enabled = !st.disabledScreens.contains(screen.localizedName)
            let show = enabled && (st.showMode == .always || !state.visible)
            guard show else { panels[screen]?.orderOut(nil); continue }

            let panel = panels[screen] ?? ClockPanel()
            panels[screen] = panel
            let barHeight = state.height ?? max(screen.safeAreaInsets.top, NSStatusBar.system.thickness)
            panel.layout(text: text, on: screen, menuBarHeight: barHeight, settingsVersion: settingsVersion)
            if !panel.isVisible { panel.alphaValue = targetAlpha(panel); panel.orderFrontRegardless() }
        }
        updateHoverFade()
    }

    func targetAlpha(_ p: ClockPanel) -> CGFloat {
        guard Settings.shared.fadeOnHover else { return 1 }
        return p.frame.insetBy(dx: -24, dy: -24).contains(NSEvent.mouseLocation) ? 0.12 : 1
    }

    func updateHoverFade() {
        for p in panels.values where p.isVisible {
            let a = targetAlpha(p)
            if abs(p.alphaValue - a) > 0.01 {
                NSAnimationContext.runAnimationGroup { ctx in ctx.duration = 0.15; p.animator().alphaValue = a }
            }
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let st = Settings.shared

        func header(_ t: String) { let i = NSMenuItem(title: t, action: nil, keyEquivalent: ""); i.isEnabled = false; menu.addItem(i) }
        func item(_ t: String, on: Bool, _ action: @escaping () -> Void) {
            let i = ClosureMenuItem(title: t, action: action); i.state = on ? .on : .off; menu.addItem(i)
        }

        header("Show")
        for m in ShowMode.allCases { item(m.title, on: st.showMode == m) { st.showMode = m } }
        menu.addItem(.separator())
        header("Corner")
        for c in Corner.allCases { item(c.title, on: st.corner == c) { st.corner = c } }
        menu.addItem(.separator())
        header("Format")
        item("24-hour", on: st.use24h) { st.use24h.toggle() }
        item("Seconds", on: st.showSeconds) { st.showSeconds.toggle() }
        item("Date", on: st.showDate) { st.showDate.toggle() }
        let sizes = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        sizes.submenu = NSMenu()
        for f in FontSize.allCases {
            let i = ClosureMenuItem(title: f.title) { st.fontSize = f }; i.state = st.fontSize == f ? .on : .off
            sizes.submenu?.addItem(i)
        }
        menu.addItem(sizes)
        item("Background", on: st.background) { st.background.toggle() }
        item("Fade when mouse is near", on: st.fadeOnHover) { st.fadeOnHover.toggle() }
        menu.addItem(.separator())
        header("Displays")
        for s in NSScreen.screens {
            let name = s.localizedName
            item(name, on: !st.disabledScreens.contains(name)) {
                var d = st.disabledScreens
                if d.contains(name) { d.remove(name) } else { d.insert(name) }
                st.disabledScreens = d
            }
        }
        menu.addItem(.separator())
        item("Launch at login", on: SMAppService.mainApp.status == .enabled) {
            do {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
                else { try SMAppService.mainApp.register() }
            } catch { NSLog("Hourglance: launch at login failed: \(error)") }
        }
        menu.addItem(NSMenuItem(title: "Quit Hourglance", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
}

final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void
    init(title: String, action: @escaping () -> Void) {
        handler = action
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError() }
    @objc private func fire() { handler() }
}

// MARK: - Main

let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.setActivationPolicy(.accessory)   // no Dock icon
app.run()
