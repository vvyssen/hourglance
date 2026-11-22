import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("settingsTab") var tab = "time"   // reopens on the last tab
    var body: some View {
        TabView(selection: $tab) {
            TimeTab().tabItem { Label("Time", systemImage: "clock") }.tag("time")
            StyleTab().tabItem { Label("Style", systemImage: "paintpalette") }.tag("style")
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }.tag("general")
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - Live preview (same text and style the real clock uses)

struct ClockPreview: View {
    // Declared so the preview re-renders whenever any of these change.
    @AppStorage(Key.followSystem) var follow = true
    @AppStorage(Key.hourCycle) var hourCycle = HourCycle.h24
    @AppStorage(Key.seconds) var seconds = false
    @AppStorage(Key.ampm) var ampm = true
    @AppStorage(Key.weekday) var weekday = false
    @AppStorage(Key.date) var date = false
    @AppStorage(Key.dateStyle) var dateStyle = DateStyle.system
    @AppStorage(Key.datePattern) var datePattern = "yyyy.MM.dd"
    @AppStorage(Key.dateFirst) var dateFirst = true
    @AppStorage(Key.shape) var shape = ClockShape.roundedRect
    @AppStorage(Key.cornerRadius) var cornerRadius = 6.0
    @AppStorage(Key.bgPreset) var bgPreset = BgPreset.blackTranslucent
    @AppStorage(Key.bgColor) var bgColor = "00000099"
    @AppStorage(Key.textMode) var textMode = TextColorMode.auto
    @AppStorage(Key.textColor) var textColor = "FFFFFFFF"
    @AppStorage(Key.fontSize) var fontSize = 13.0
    @AppStorage(Key.weight) var weight = FontWeight.medium
    @AppStorage(Key.separateAppearance) var separate = false
    @AppStorage(Key.themed(Key.bgPreset, dark: true)) var bgPresetDark = BgPreset.blackTranslucent
    @AppStorage(Key.themed(Key.bgColor, dark: true)) var bgColorDark = "00000099"
    @AppStorage(Key.themed(Key.textMode, dark: true)) var textModeDark = TextColorMode.auto
    @AppStorage(Key.themed(Key.textColor, dark: true)) var textColorDark = "FFFFFFFF"
    @AppStorage(Key.timeZoneMode) var tzMode = TimeZoneMode.system
    @AppStorage(Key.timeZoneID) var tzID = ""
    @AppStorage(Key.showZone) var showZone = false
    @AppStorage(Key.zoneStyle) var zoneStyle = ZoneStyle.abbreviation

    var body: some View {
        let format = ClockFormat()   // rebuilt from current prefs on every render
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            HStack(spacing: 0) {
                sample(format.string(from: ctx.date), dark: false,
                       label: separate ? "Light mode" : "On light", backdrop: [Color(white: 0.96), Color(white: 0.86)])
                sample(format.string(from: ctx.date), dark: true,
                       label: separate ? "Dark mode" : "On dark", backdrop: [Color(white: 0.22), Color(white: 0.08)])
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(height: 72)
    }

    func sample(_ text: String, dark: Bool, label: String, backdrop: [Color]) -> some View {
        let style = Prefs.style(dark: dark)
        let scale = fontSize / 13
        let h = ceil(NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: weight.ns).boundingRectForFont.height * 0.82 + 4 * scale)
        let padX = shape == .capsule ? max(8 * scale, h * 0.45) : 8 * scale
        let bg = style.background.map { Color(nsColor: $0) } ?? .clear
        let radius = shape == .capsule ? h / 2 : min(cornerRadius * scale, h / 2)
        return ZStack {
            LinearGradient(colors: backdrop, startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(text)
                .font(.system(size: fontSize, weight: Font.Weight(weight)).monospacedDigit())
                .foregroundColor(Color(nsColor: style.text))
                .shadow(color: style.shadow ? .black.opacity(0.8) : .clear, radius: 1.5)
                .lineLimit(1)
                .padding(.horizontal, padX)
                .frame(height: h)
                .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(bg))
            Text(label).font(.system(size: 10)).foregroundColor(dark ? .white.opacity(0.45) : .black.opacity(0.4))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(6)
        }
    }
}

extension Font.Weight {
    init(_ w: FontWeight) {
        switch w {
        case .regular: self = .regular
        case .medium: self = .medium
        case .semibold: self = .semibold
        case .bold: self = .bold
        }
    }
}

// MARK: - Time

struct TimeTab: View {
    @AppStorage(Key.followSystem) var follow = true
    @AppStorage(Key.hourCycle) var hourCycle = HourCycle.h24
    @AppStorage(Key.seconds) var seconds = false
    @AppStorage(Key.ampm) var ampm = true
    @AppStorage(Key.weekday) var weekday = false
    @AppStorage(Key.date) var date = false
    @AppStorage(Key.dateStyle) var dateStyle = DateStyle.system
    @AppStorage(Key.datePattern) var datePattern = "yyyy.MM.dd"
    @AppStorage(Key.dateFirst) var dateFirst = true
    @AppStorage(Key.timeZoneMode) var tzMode = TimeZoneMode.system
    @AppStorage(Key.showZone) var showZone = false
    @AppStorage(Key.zoneStyle) var zoneStyle = ZoneStyle.abbreviation
    @AppStorage(Key.timeZoneID) var tzID = ""

    var body: some View {
        let sys = SystemClockPrefs.read()
        Form {
            Section { ClockPreview() }

            Section {
                Toggle("Follow system time format", isOn: $follow)
                if follow {
                    Text("Currently \(sys.is24Hour ? "24-hour" : "12-hour")\(sys.seconds ? ", with seconds" : "")\(!sys.is24Hour && sys.ampm ? ", with AM/PM" : ""). Change it in System Settings › General › Date & Time (24-hour) and › Control Center › Clock Options (seconds, AM/PM).")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Picker("Hours", selection: $hourCycle) {
                        ForEach(HourCycle.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                    Toggle("Show seconds", isOn: $seconds)
                    if hourCycle == .h12 { Toggle("Show AM/PM", isOn: $ampm) }
                }
            } header: { Text("Time") }

            Section {
                Toggle("Show weekday", isOn: $weekday)
                Toggle("Show date", isOn: $date)
                if date {
                    Picker("Date format", selection: $dateStyle) {
                        ForEach(DateStyle.allCases) { s in
                            Text(s == .system ? "System (\(ClockFormat.sample(s)))" : ClockFormat.sample(s)).tag(s)
                        }
                    }
                    if dateStyle == .custom {
                        TextField("Pattern", text: $datePattern)
                        Text("Unicode date pattern, e.g. yyyy.MM.dd · MMM d · d MMMM · EEEE. Letters: y year, M month, d day, E weekday.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if weekday || date {
                    Picker("Order", selection: $dateFirst) {
                        Text("Date before time").tag(true)
                        Text("Time before date").tag(false)
                    }.pickerStyle(.segmented)
                }
            } header: { Text("Date") }

            Section {
                Picker("Time zone", selection: $tzMode) {
                    Text("Follow macOS (\(sys.timeZone))").tag(TimeZoneMode.system)
                    Text("Custom").tag(TimeZoneMode.custom)
                }
                if tzMode == .custom { TimeZonePicker() }
                Toggle("Show time zone name", isOn: $showZone)
                if showZone {
                    let tz = Prefs.customTimeZone ?? .current
                    Picker("Name style", selection: $zoneStyle) {
                        ForEach(ZoneStyle.allCases) { st in
                            Text("\(st.title) (\(ClockFormat.zoneSample(st, tz)))").tag(st)
                        }
                    }
                }
            } header: { Text("Time zone") }
        }
        .formStyle(.grouped)
    }
}

/// Searchable list of every time zone: matches identifier, city, localized name and abbreviation.
struct TimeZonePicker: View {
    @AppStorage(Key.timeZoneID) var tzID = ""
    @ObservedObject var model = TimeZoneSearch.shared

    var body: some View {
        if let z = model.all.first(where: { $0.id == tzID }) {
            LabeledContent("Selected", value: "\(z.city) · \(z.id) · \(z.offset)")
        }
        TextField("Search", text: $model.query, prompt: Text("City, region, abbreviation or UTC+8"))
            .textFieldStyle(.roundedBorder)
        List(model.results(selected: tzID), id: \.id) { z in
            HStack {
                Text(z.city)
                Text(z.id).foregroundStyle(.secondary).font(.caption)
                Spacer()
                Text(z.offset).monospacedDigit().foregroundStyle(.secondary)
                if z.id == tzID { Image(systemName: "checkmark").foregroundColor(.accentColor) }
            }
            .contentShape(Rectangle())
            .onTapGesture { tzID = z.id }
        }
        .frame(height: 150)
    }
}

final class TimeZoneSearch: ObservableObject {
    static let shared = TimeZoneSearch()
    struct Zone { let id, city, name, abbr, offset: String }
    let all: [Zone] = TimeZone.knownTimeZoneIdentifiers.compactMap { id in
        guard let tz = TimeZone(identifier: id) else { return nil }
        let city = id.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? id
        return Zone(id: id, city: city, name: tz.localizedName(for: .generic, locale: .current) ?? "",
                    abbr: tz.abbreviation() ?? "", offset: ClockFormat.offset(tz))
    }.sorted { $0.city < $1.city }
    @Published var query = ""
    /// With no query, the selected zone is listed first.
    func results(selected: String) -> [Zone] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all.filter { $0.id == selected } + all.filter { $0.id != selected } }
        return all.filter { "\($0.id) \($0.city) \($0.name) \($0.abbr) \($0.offset)".lowercased().contains(q) }
    }
}

// MARK: - Style

struct StyleTab: View {
    @AppStorage(Key.shape) var shape = ClockShape.roundedRect
    @AppStorage(Key.cornerRadius) var cornerRadius = 6.0
    @AppStorage(Key.separateAppearance) var separate = false
    @AppStorage("styleEditingDark") var editingDark = Prefs.systemIsDark
    @AppStorage(Key.fontSize) var fontSize = 13.0
    @AppStorage(Key.weight) var weight = FontWeight.medium

    var body: some View {
        Form {
            Section { ClockPreview() }

            Section {
                Picker("Shape", selection: $shape) {
                    ForEach(ClockShape.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
                if shape == .roundedRect {
                    LabeledContent("Corner radius") {
                        Slider(value: $cornerRadius, in: 0...12, step: 1)
                        Text("\(Int(cornerRadius))").monospacedDigit().frame(width: 24, alignment: .trailing)
                    }
                }
            } header: { Text("Shape") }

            Section {
                Toggle("Separate colors for light and dark mode", isOn: $separate)
                if separate {
                    Picker("Editing", selection: $editingDark) {
                        Text("Light mode").tag(false)
                        Text("Dark mode").tag(true)
                    }.pickerStyle(.segmented)
                }
                ColorsEditor(dark: separate && editingDark).id(separate && editingDark)
            } header: { Text("Colors") }

            Section {
                LabeledContent("Size") {
                    Slider(value: $fontSize, in: 10...24, step: 1)
                    Text("\(Int(fontSize)) pt").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
                Picker("Weight", selection: $weight) {
                    ForEach(FontWeight.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }.pickerStyle(.segmented)
            } header: { Text("Text") }
        }
        .formStyle(.grouped)
    }
}

/// Background + text color for one appearance (light-mode keys, or the *Dark variants).
struct ColorsEditor: View {
    let dark: Bool
    @AppStorage var bgPreset: BgPreset
    @AppStorage var bgColor: String
    @AppStorage var textMode: TextColorMode
    @AppStorage var textColor: String

    init(dark: Bool) {
        self.dark = dark
        _bgPreset = AppStorage(wrappedValue: .blackTranslucent, Key.themed(Key.bgPreset, dark: dark))
        _bgColor = AppStorage(wrappedValue: "00000099", Key.themed(Key.bgColor, dark: dark))
        _textMode = AppStorage(wrappedValue: .auto, Key.themed(Key.textMode, dark: dark))
        _textColor = AppStorage(wrappedValue: "FFFFFFFF", Key.themed(Key.textColor, dark: dark))
    }

    var body: some View {
        LabeledContent("Background") {
            HStack(spacing: 8) {
                ForEach(BgPreset.allCases.filter { $0 != .custom }) { p in swatch(p) }
            }
        }
        ColorPicker("Custom background", selection: hexBinding($bgColor, onSet: { bgPreset = .custom }), supportsOpacity: true)
        Picker("Text color", selection: $textMode) {
            Text("Automatic").tag(TextColorMode.auto)
            Text("Custom").tag(TextColorMode.custom)
        }.pickerStyle(.segmented)
        if textMode == .custom {
            ColorPicker("Custom text color", selection: hexBinding($textColor), supportsOpacity: true)
        }
    }

    func swatch(_ p: BgPreset) -> some View {
        Button { bgPreset = p } label: {
            ZStack {
                Checkerboard().clipShape(Circle())
                if let c = p.color(customHex: bgColor) { Circle().fill(Color(nsColor: c)) }
                if p == .none { Image(systemName: "slash.circle").font(.system(size: 20, weight: .light)).foregroundStyle(.secondary) }
            }
            .frame(width: 24, height: 24)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: bgPreset == p ? 2.5 : 0).padding(-3))
            .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(p.title)
    }

    func hexBinding(_ hex: Binding<String>, onSet: @escaping () -> Void = {}) -> Binding<Color> {
        Binding(get: { Color(nsColor: NSColor(hex: hex.wrappedValue) ?? .black) },
                set: { hex.wrappedValue = NSColor($0).hexString; onSet() })
    }
}

struct Checkerboard: View {
    var body: some View {
        Canvas { ctx, size in
            let s: CGFloat = 4
            for y in stride(from: 0, to: size.height, by: s) {
                for x in stride(from: 0, to: size.width, by: s) where (Int(x / s) + Int(y / s)) % 2 == 0 {
                    ctx.fill(Path(CGRect(x: x, y: y, width: s, height: s)), with: .color(.gray.opacity(0.35)))
                }
            }
        }
        .background(Color.white)
    }
}

// MARK: - General

struct GeneralTab: View {
    @AppStorage(Key.showMode) var showMode = ShowMode.menuBarHidden
    @AppStorage(Key.corner) var corner = Corner.topRight
    @AppStorage(Key.fade) var fade = true
    @AppStorage(Key.clickModifier) var clickModifier = ClickModifier.option
    @AppStorage(Key.statusItem) var statusItem = true
    @ObservedObject var model = GeneralModel.shared

    var body: some View {
        Form {
            Section {
                Picker("Show the clock", selection: $showMode) {
                    ForEach(ShowMode.allCases) { Text($0.title).tag($0) }
                }
                Picker("Corner", selection: $corner) {
                    ForEach(Corner.allCases) { Text($0.title).tag($0) }
                }
            } header: { Text("Placement") }

            Section {
                ForEach(NSScreen.screens, id: \.localizedName) { s in
                    Toggle(s.localizedName, isOn: Binding(
                        get: { !model.disabled.contains(s.localizedName) },
                        set: { on in
                            if on { model.disabled.remove(s.localizedName) } else { model.disabled.insert(s.localizedName) }
                            Prefs.d.set(Array(model.disabled), forKey: Key.disabledScreens)
                        }))
                }
            } header: { Text("Displays") }

            Section {
                Toggle("Fade when the pointer is near", isOn: $fade)
                Picker("Click the clock with", selection: $clickModifier) {
                    ForEach(ClickModifier.allCases) { Text($0.symbol).tag($0) }
                }.pickerStyle(.segmented)
                Text("Hold \(clickModifier.symbol) and click the clock to open its menu. Without the modifier, clicks pass through to the app underneath.")
                    .font(.caption).foregroundStyle(.secondary)
                ShortcutRecorder()
            } header: { Text("Interaction") }

            Section {
                Toggle("Show menu bar icon", isOn: $statusItem)
                if !statusItem {
                    Text("To get back here: \(clickModifier.symbol)-click the clock, or open Hourglance again from Finder or Spotlight.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: { on in
                    do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                    catch { NSLog("Hourglance: launch at login failed: \(error)") }
                    model.loginEnabled = SMAppService.mainApp.status == .enabled
                }))
            } header: { Text("App") }
        }
        .formStyle(.grouped)
    }
}

final class GeneralModel: ObservableObject {
    static let shared = GeneralModel()
    @Published var disabled = Prefs.disabledScreens
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
}

final class RecorderModel: ObservableObject {
    static let shared = RecorderModel()
    @Published var recording = false
    var monitor: Any?
}

struct ShortcutRecorder: View {
    @AppStorage(Key.hotKeyEnabled) var enabled = true
    @AppStorage(Key.hotKeyCode) var code = 17
    @AppStorage(Key.hotKeyMods) var mods = 0
    @AppStorage(Key.hotKeyDisplay) var display = "⌃⌥⌘T"
    @ObservedObject var model = RecorderModel.shared

    var body: some View {
        HStack {
            Toggle("Hide / show shortcut", isOn: $enabled)
            Spacer()
            Button(model.recording ? "Press keys… (Esc cancels)" : display) { model.recording ? stop() : start() }
                .disabled(!enabled)
                .frame(minWidth: 110)
        }
    }

    func start() {
        model.recording = true
        model.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            if e.keyCode == 53 { stop(); return nil }                         // Esc
            let m = e.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !m.isDisjoint(with: [.command, .option, .control]) else { NSSound.beep(); return nil }
            code = Int(e.keyCode)
            mods = Int(m.rawValue)
            display = Self.symbols(m) + Self.keyName(e)
            stop()
            return nil
        }
    }

    func stop() {
        model.recording = false
        if let m = model.monitor { NSEvent.removeMonitor(m); model.monitor = nil }
    }

    static func symbols(_ m: NSEvent.ModifierFlags) -> String {
        (m.contains(.control) ? "⌃" : "") + (m.contains(.option) ? "⌥" : "") + (m.contains(.shift) ? "⇧" : "") + (m.contains(.command) ? "⌘" : "")
    }

    static func keyName(_ e: NSEvent) -> String {
        let special: [UInt16: String] = [49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 117: "⌦", 123: "←", 124: "→", 125: "↓", 126: "↑",
                                         122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
                                         101: "F9", 109: "F10", 103: "F11", 111: "F12"]
        if let s = special[e.keyCode] { return s }
        return (e.charactersIgnoringModifiers ?? "?").uppercased()
    }
}
