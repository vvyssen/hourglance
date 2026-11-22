import Cocoa
import SwiftUI

final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static private(set) var shared: AppController!

    var panels: [NSScreen: ClockPanel] = [:]
    var statusItem: NSStatusItem!
    let format = ClockFormat()
    var systemPrefs = SystemClockPrefs.read()
    var styleVersion = 0
    var tickTimer: Timer?
    var pollTimer: Timer?
    var nearTimer: Timer?
    var monitors: [Any] = []
    var appearanceObservation: NSKeyValueObservation?
    var settingsWindow: NSWindow?

    // Temporary hide
    var hiddenUntil: Date?
    var hiddenIndefinitely = false
    var isTemporarilyHidden: Bool {
        if hiddenIndefinitely { return true }
        if let t = hiddenUntil, t > Date() { return true }
        return false
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        AppController.shared = self
        NSApp.mainMenu = makeMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Hourglance")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        let nc = NotificationCenter.default, wnc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(prefsChanged), name: UserDefaults.didChangeNotification, object: nil)
        nc.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        nc.addObserver(self, selector: #selector(systemFormatChanged), name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        nc.addObserver(self, selector: #selector(systemFormatChanged), name: .NSSystemTimeZoneDidChange, object: nil)
        nc.addObserver(self, selector: #selector(systemFormatChanged), name: .NSSystemClockDidChange, object: nil)
        wnc.addObserver(self, selector: #selector(refresh), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        wnc.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        wnc.addObserver(self, selector: #selector(systemFormatChanged), name: NSWorkspace.didWakeNotification, object: nil)

        // Menu bar can slide in/out at any time (auto-hide): poll cheaply. Every ~2 s also re-read
        // the system clock settings (Control Center has no change notification for them).
        var n = 0
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            n += 1
            if n % 8 == 0 { self.checkSystemPrefs() }
            self.refresh()
        }
        pollTimer?.tolerance = 0.05
        scheduleTick()

        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.updateInteraction()
        } as Any)
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .flagsChanged]) { [weak self] e in
            self?.updateInteraction(); return e
        } as Any)

        HotKey.shared.handler = { [weak self] in self?.toggleHidden() }
        applyPrefs()

        AppIcon.apply()
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { _, _ in
            DispatchQueue.main.async { AppIcon.apply() }
        }
    }

    /// Opening the app again (Finder, Spotlight, `open`) shows the settings — the way back in
    /// when the menu bar icon is turned off.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings(); return true
    }

    // MARK: Preferences

    @objc func prefsChanged() { DispatchQueue.main.async { self.applyPrefs() } }

    func applyPrefs() {
        format.rebuild(system: systemPrefs)
        styleVersion += 1
        statusItem.isVisible = Prefs.showStatusItem
        if Prefs.hotKeyEnabled { HotKey.shared.register(keyCode: Prefs.hotKeyCode, modifiers: Prefs.hotKeyMods) }
        else { HotKey.shared.unregister() }
        refresh()
    }

    @objc func systemFormatChanged() {
        NSTimeZone.resetSystemTimeZone()
        systemPrefs = SystemClockPrefs.read()
        format.rebuild(system: systemPrefs)
        styleVersion += 1
        refresh()
    }

    func checkSystemPrefs() {
        let now = SystemClockPrefs.read()
        if now != systemPrefs { systemFormatChanged() }
    }

    @objc func screensChanged() { MenuBar.invalidateHeights(); refresh() }

    // MARK: Clock

    // Fire exactly on each second boundary so the seconds digit is never late.
    func scheduleTick() {
        let next = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 1.0005)
        tickTimer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            self?.refresh(); self?.scheduleTick()
        }
        RunLoop.main.add(tickTimer!, forMode: .common)
    }

    @objc func refresh() {
        if let t = hiddenUntil, t <= Date() { hiddenUntil = nil }
        let screens = NSScreen.screens
        let states = MenuBar.states(for: screens)
        let text = format.string(from: Date())
        let disabled = Prefs.disabledScreens, always = Prefs.showMode == .always, hidden = isTemporarilyHidden

        for (screen, panel) in panels where !screens.contains(screen) {
            panel.orderOut(nil); panels[screen] = nil
        }
        for screen in screens {
            let state = states[screen] ?? .init(visible: false, height: nil)
            let show = !hidden && !disabled.contains(screen.localizedName) && (always || !state.visible)
            guard show else { panels[screen]?.orderOut(nil); continue }

            let panel = panels[screen] ?? makePanel()
            panels[screen] = panel
            let barHeight = state.height ?? max(screen.safeAreaInsets.top, NSStatusBar.system.thickness)
            panel.layout(text: text, on: screen, menuBarHeight: barHeight, styleVersion: styleVersion)
            if !panel.isVisible { panel.alphaValue = targetAlpha(panel); panel.orderFrontRegardless() }
        }
        updateInteraction()
    }

    func makePanel() -> ClockPanel {
        let p = ClockPanel()
        p.box.onClick = { [weak self] event, view in
            guard let self else { return }
            NSMenu.popUpContextMenu(self.makeQuickMenu(), with: event, for: view)
        }
        return p
    }

    // MARK: Hover fade + modifier-click

    func modifierHeld() -> Bool { NSEvent.modifierFlags.contains(Prefs.clickModifier.flag) }

    func targetAlpha(_ p: ClockPanel) -> CGFloat {
        let near = p.frame.insetBy(dx: -24, dy: -24).contains(NSEvent.mouseLocation)
        if near && modifierHeld() { return 1 }               // about to be clicked: show it fully
        guard Prefs.fade else { return 1 }
        return near ? 0.12 : 1
    }

    func updateInteraction() {
        let mouse = NSEvent.mouseLocation
        var anyNear = false
        for p in panels.values where p.isVisible {
            let near = p.frame.insetBy(dx: -24, dy: -24).contains(mouse)
            anyNear = anyNear || near
            let clickable = near && modifierHeld()
            if p.ignoresMouseEvents == clickable { p.ignoresMouseEvents = !clickable }
            let a = targetAlpha(p)
            if abs(p.alphaValue - a) > 0.01 {
                NSAnimationContext.runAnimationGroup { ctx in ctx.duration = 0.15; p.animator().alphaValue = a }
            }
        }
        // Modifier keys can't be observed globally without Accessibility permission, so while the
        // pointer is near a clock, poll them quickly.
        if anyNear && nearTimer == nil {
            nearTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.updateInteraction() }
        } else if !anyNear, let t = nearTimer {
            t.invalidate(); nearTimer = nil
        }
    }

    // MARK: Hide / show

    func hide(for minutes: Double?) {
        if let m = minutes { hiddenUntil = Date().addingTimeInterval(m * 60); hiddenIndefinitely = false }
        else { hiddenIndefinitely = true; hiddenUntil = nil }
        refresh()
    }

    func showAgain() { hiddenIndefinitely = false; hiddenUntil = nil; refresh() }

    func toggleHidden() { isTemporarilyHidden ? showAgain() : hide(for: nil) }

    // MARK: Menus

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for item in makeQuickMenu().items { item.menu?.removeItem(item); menu.addItem(item) }
    }

    func makeQuickMenu() -> NSMenu {
        let menu = NSMenu()
        let hk = Prefs.hotKeyEnabled ? "  \(Prefs.hotKeyDisplay)" : ""
        if isTemporarilyHidden {
            var title = "Show Clock"
            if let t = hiddenUntil {
                let f = DateFormatter(); f.timeStyle = .short
                title += " (hidden until \(f.string(from: t)))"
            }
            menu.addItem(ClosureMenuItem(title: title + hk) { [weak self] in self?.showAgain() })
        } else {
            let hideItem = NSMenuItem(title: "Hide Clock", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for (t, m) in [("For 5 Minutes", 5.0), ("For 30 Minutes", 30), ("For 1 Hour", 60)] {
                sub.addItem(ClosureMenuItem(title: t) { [weak self] in self?.hide(for: m) })
            }
            sub.addItem(ClosureMenuItem(title: "Until I Show It Again" + hk) { [weak self] in self?.hide(for: nil) })
            hideItem.submenu = sub
            menu.addItem(hideItem)
        }
        menu.addItem(.separator())
        let onlyHidden = ClosureMenuItem(title: "Only When Menu Bar Is Hidden") {
            Prefs.d.set((Prefs.showMode == .always ? ShowMode.menuBarHidden : .always).rawValue, forKey: Key.showMode)
        }
        onlyHidden.state = Prefs.showMode == .menuBarHidden ? .on : .off
        menu.addItem(onlyHidden)
        menu.addItem(.separator())
        let settings = ClosureMenuItem(title: "Settings…") { [weak self] in self?.openSettings() }
        settings.keyEquivalent = ","
        menu.addItem(settings)
        menu.addItem(NSMenuItem(title: "Quit Hourglance", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    /// Needed so ⌘C/⌘V/⌘W work in the settings window of an accessory app.
    func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem(); appItem.submenu = NSMenu()
        appItem.submenu?.addItem(NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        appItem.submenu?.addItem(NSMenuItem(title: "Quit Hourglance", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        main.addItem(appItem)
        let editItem = NSMenuItem(); editItem.submenu = NSMenu(title: "Edit")
        for (t, sel, k) in [("Undo", "undo:", "z"), ("Redo", "redo:", "Z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"),
                            ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editItem.submenu?.addItem(NSMenuItem(title: t, action: Selector(sel), keyEquivalent: k))
        }
        main.addItem(editItem)
        return main
    }

    // MARK: Settings window

    func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "Hourglance Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
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
