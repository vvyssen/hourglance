import Cocoa

// All preferences live in UserDefaults. The settings window binds to them with @AppStorage
// and the app re-reads them on UserDefaults.didChangeNotification.

enum Key {
    static let showMode = "showMode", corner = "corner", disabledScreens = "disabledScreens"
    static let followSystem = "followSystemFormat", hourCycle = "hourCycle", seconds = "customSeconds", ampm = "customAMPM"
    static let weekday = "showWeekday", date = "showDateV2", dateStyle = "dateStyle", datePattern = "datePattern", dateFirst = "dateFirst"
    static let shape = "shape", cornerRadius = "cornerRadius", bgPreset = "bgPreset", bgColor = "bgColor"
    static let textMode = "textColorMode", textColor = "textColor", fontSize = "fontPoints", weight = "fontWeight"
    static let fade = "fadeOnHover", clickModifier = "clickModifier", statusItem = "showStatusItem"
    static let separateAppearance = "separateAppearance"
    static let timeZoneMode = "timeZoneMode", timeZoneID = "timeZoneID", showZone = "showTimeZone", zoneStyle = "timeZoneStyle"
    /// Light-mode keys are the plain ones; dark-mode variants add this suffix.
    static func themed(_ key: String, dark: Bool) -> String { dark ? key + "Dark" : key }
    static let hotKeyEnabled = "hotKeyEnabled", hotKeyCode = "hotKeyCode", hotKeyMods = "hotKeyMods", hotKeyDisplay = "hotKeyDisplay"
}

enum Corner: String, CaseIterable, Identifiable {
    case topRight, topLeft, bottomRight, bottomLeft
    var id: Self { self }
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

enum ShowMode: String, CaseIterable, Identifiable {
    case menuBarHidden, always
    var id: Self { self }
    var title: String { self == .always ? "Always" : "Only when the menu bar is hidden" }
}

enum HourCycle: String, CaseIterable, Identifiable {
    case h24, h12
    var id: Self { self }
    var title: String { self == .h24 ? "24-hour" : "12-hour" }
}

enum DateStyle: String, CaseIterable, Identifiable {
    case system, ymd, ymdSlash, mdSlash, dmSlash, mdy, dmy, monthDay, dayMonth, custom
    var id: Self { self }
    /// nil = locale-driven (system) or user pattern (custom)
    var pattern: String? {
        switch self {
        case .system, .custom: return nil
        case .ymd: return "yyyy-MM-dd"
        case .ymdSlash: return "yyyy/M/d"
        case .mdSlash: return "M/d"
        case .dmSlash: return "d/M"
        case .mdy: return "M/d/yyyy"
        case .dmy: return "d/M/yyyy"
        case .monthDay: return "MMM d"
        case .dayMonth: return "d MMM"
        }
    }
}

enum ClockShape: String, CaseIterable, Identifiable {
    case roundedRect, capsule
    var id: Self { self }
    var title: String { self == .capsule ? "Capsule" : "Rounded rectangle" }
}

enum BgPreset: String, CaseIterable, Identifiable {
    case blackTranslucent, black, graphite, whiteTranslucent, blue, amber, green, none, custom
    var id: Self { self }
    var title: String {
        switch self {
        case .blackTranslucent: return "Translucent black"
        case .black: return "Black"
        case .graphite: return "Graphite"
        case .whiteTranslucent: return "Translucent white"
        case .blue: return "Blue"
        case .amber: return "Amber"
        case .green: return "Green"
        case .none: return "None"
        case .custom: return "Custom"
        }
    }
    func color(customHex: String) -> NSColor? {
        switch self {
        case .blackTranslucent: return NSColor(white: 0, alpha: 0.6)
        case .black: return .black
        case .graphite: return NSColor(hex: "3A3D44E0")
        case .whiteTranslucent: return NSColor(white: 1, alpha: 0.75)
        case .blue: return NSColor(hex: "0A84FFE6")
        case .amber: return NSColor(hex: "FF9F0AE6")
        case .green: return NSColor(hex: "30D158E6")
        case .none: return nil
        case .custom: return NSColor(hex: customHex) ?? .black
        }
    }
}

enum TimeZoneMode: String, CaseIterable, Identifiable {
    case system, custom
    var id: Self { self }
}

enum ZoneStyle: String, CaseIterable, Identifiable {
    case abbreviation, city, offset, fullName
    var id: Self { self }
    var title: String {
        switch self {
        case .abbreviation: return "Abbreviation"
        case .city: return "City"
        case .offset: return "UTC offset"
        case .fullName: return "Full name"
        }
    }
}

enum TextColorMode: String, CaseIterable, Identifiable {
    case auto, custom
    var id: Self { self }
}

enum FontWeight: String, CaseIterable, Identifiable {
    case regular, medium, semibold, bold
    var id: Self { self }
    var ns: NSFont.Weight { [.regular: .regular, .medium: .medium, .semibold: .semibold, .bold: .bold][self]! }
}

enum ClickModifier: String, CaseIterable, Identifiable {
    case option, command, control, shift
    var id: Self { self }
    var flag: NSEvent.ModifierFlags { [.option: .option, .command: .command, .control: .control, .shift: .shift][self]! }
    var symbol: String { [.option: "⌥", .command: "⌘", .control: "⌃", .shift: "⇧"][self]! }
}

enum Prefs {
    static var d: UserDefaults { .standard }

    static func registerDefaults() {
        d.register(defaults: [
            Key.showMode: ShowMode.menuBarHidden.rawValue, Key.corner: Corner.topRight.rawValue,
            Key.followSystem: true, Key.hourCycle: HourCycle.h24.rawValue, Key.seconds: false, Key.ampm: true,
            Key.weekday: false, Key.date: false, Key.dateStyle: DateStyle.system.rawValue,
            Key.datePattern: "yyyy.MM.dd", Key.dateFirst: true,
            Key.shape: ClockShape.roundedRect.rawValue, Key.cornerRadius: 6.0,
            Key.bgPreset: BgPreset.blackTranslucent.rawValue, Key.bgColor: "00000099",
            Key.textMode: TextColorMode.auto.rawValue, Key.textColor: "FFFFFFFF",
            Key.fontSize: 13.0, Key.weight: FontWeight.medium.rawValue,
            Key.themed(Key.bgPreset, dark: true): BgPreset.blackTranslucent.rawValue,
            Key.themed(Key.bgColor, dark: true): "00000099",
            Key.themed(Key.textMode, dark: true): TextColorMode.auto.rawValue,
            Key.themed(Key.textColor, dark: true): "FFFFFFFF",
            Key.separateAppearance: false,
            Key.timeZoneMode: TimeZoneMode.system.rawValue, Key.timeZoneID: TimeZone.current.identifier,
            Key.showZone: false, Key.zoneStyle: ZoneStyle.abbreviation.rawValue,
            Key.fade: true, Key.clickModifier: ClickModifier.option.rawValue, Key.statusItem: true,
            Key.hotKeyEnabled: true, Key.hotKeyCode: 17,   // T
            Key.hotKeyMods: Int(NSEvent.ModifierFlags([.control, .option, .command]).rawValue),
            Key.hotKeyDisplay: "⌃⌥⌘T",
        ])
    }

    private static func e<T: RawRepresentable>(_ k: String, _ def: T) -> T where T.RawValue == String {
        d.string(forKey: k).flatMap(T.init(rawValue:)) ?? def
    }

    static var showMode: ShowMode { e(Key.showMode, .menuBarHidden) }
    static var corner: Corner { e(Key.corner, .topRight) }
    static var disabledScreens: Set<String> { Set(d.stringArray(forKey: Key.disabledScreens) ?? []) }
    static var followSystem: Bool { d.bool(forKey: Key.followSystem) }
    static var hourCycle: HourCycle { e(Key.hourCycle, .h24) }
    static var seconds: Bool { d.bool(forKey: Key.seconds) }
    static var ampm: Bool { d.bool(forKey: Key.ampm) }
    static var weekday: Bool { d.bool(forKey: Key.weekday) }
    static var date: Bool { d.bool(forKey: Key.date) }
    static var dateStyle: DateStyle { e(Key.dateStyle, .system) }
    static var datePattern: String { d.string(forKey: Key.datePattern) ?? "yyyy.MM.dd" }
    static var dateFirst: Bool { d.bool(forKey: Key.dateFirst) }
    static var shape: ClockShape { e(Key.shape, .roundedRect) }
    static var cornerRadius: CGFloat { CGFloat(d.double(forKey: Key.cornerRadius)) }
    static var fontSize: CGFloat { CGFloat(d.double(forKey: Key.fontSize)) }
    static var weight: FontWeight { e(Key.weight, .medium) }
    static var fade: Bool { d.bool(forKey: Key.fade) }
    static var clickModifier: ClickModifier { e(Key.clickModifier, .option) }
    static var showStatusItem: Bool { d.bool(forKey: Key.statusItem) }
    static var hotKeyEnabled: Bool { d.bool(forKey: Key.hotKeyEnabled) }
    static var hotKeyCode: Int { d.integer(forKey: Key.hotKeyCode) }
    static var hotKeyMods: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: UInt(d.integer(forKey: Key.hotKeyMods))) }
    static var hotKeyDisplay: String { d.string(forKey: Key.hotKeyDisplay) ?? "" }

    static var separateAppearance: Bool { d.bool(forKey: Key.separateAppearance) }
    static var systemIsDark: Bool { NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }

    static var timeZoneMode: TimeZoneMode { e(Key.timeZoneMode, .system) }
    /// nil = follow macOS (autoupdating).
    static var customTimeZone: TimeZone? {
        timeZoneMode == .custom ? d.string(forKey: Key.timeZoneID).flatMap(TimeZone.init(identifier:)) : nil
    }
    static var showZone: Bool { d.bool(forKey: Key.showZone) }
    static var zoneStyle: ZoneStyle { e(Key.zoneStyle, .abbreviation) }

    /// Resolved colors, shared by the real clock and the settings preview. `dark` picks the
    /// dark-mode set when separate light/dark colors are on; nil means "the current system appearance".
    static func style(dark: Bool? = nil) -> ClockStyle {
        let useDark = separateAppearance && (dark ?? systemIsDark)
        let preset = e(Key.themed(Key.bgPreset, dark: useDark), BgPreset.blackTranslucent)
        let bg = preset.color(customHex: d.string(forKey: Key.themed(Key.bgColor, dark: useDark)) ?? "00000099")
        let mode = e(Key.themed(Key.textMode, dark: useDark), TextColorMode.auto)
        let text: NSColor
        if mode == .custom, let c = NSColor(hex: d.string(forKey: Key.themed(Key.textColor, dark: useDark)) ?? "") {
            text = c
        } else if let bg, bg.alphaComponent >= 0.35 {
            text = bg.luminance > 0.6 ? .black : .white
        } else {
            text = .white
        }
        // Bare text over unknown content needs a shadow to stay legible.
        return ClockStyle(background: bg, text: text, shadow: (bg?.alphaComponent ?? 0) < 0.35)
    }
}

struct ClockStyle { let background: NSColor?; let text: NSColor; let shadow: Bool }

extension NSColor {
    convenience init?(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard s.count == 6 || s.count == 8, var v = UInt64(s, radix: 16) else { return nil }
        if s.count == 6 { v = v << 8 | 0xff }
        self.init(srgbRed: CGFloat((v >> 24) & 0xff) / 255, green: CGFloat((v >> 16) & 0xff) / 255,
                  blue: CGFloat((v >> 8) & 0xff) / 255, alpha: CGFloat(v & 0xff) / 255)
    }
    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        func b(_ x: CGFloat) -> Int { Int((max(0, min(1, x)) * 255).rounded()) }
        return String(format: "%02X%02X%02X%02X", b(c.redComponent), b(c.greenComponent), b(c.blueComponent), b(c.alphaComponent))
    }
    var luminance: CGFloat {
        let c = usingColorSpace(.sRGB) ?? self
        return 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
    }
}
