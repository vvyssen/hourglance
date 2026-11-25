import Foundation

/// What macOS itself uses for the menu bar clock.
struct SystemClockPrefs: Equatable {
    var is24Hour: Bool, seconds: Bool, ampm: Bool, locale: String, timeZone: String

    static func read() -> SystemClockPrefs {
        // 12/24-hour comes from the locale (System Settings › General › Date & Time › 24-hour time).
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.timeStyle = .short
        let fmt = f.dateFormat ?? "HH:mm"
        // Seconds and AM/PM come from the menu bar clock settings (Control Center › Clock Options).
        let domain = "com.apple.menuextra.clock" as CFString
        CFPreferencesAppSynchronize(domain)
        func flag(_ k: String, _ def: Bool) -> Bool {
            (CFPreferencesCopyAppValue(k as CFString, domain) as? NSNumber)?.boolValue ?? def
        }
        return SystemClockPrefs(is24Hour: fmt.contains("H") || fmt.contains("k"),
                                seconds: flag("ShowSeconds", false), ampm: flag("ShowAMPM", true),
                                locale: Locale.current.identifier, timeZone: TimeZone.current.identifier)
    }
}

final class ClockFormat {
    private let timeF = DateFormatter()
    private let dateF = DateFormatter()
    private let zoneF = DateFormatter()
    private var zone: TimeZone = .autoupdatingCurrent
    private var zoneStyle: ZoneStyle?
    private var hasDate = false
    private var dateFirst = true
    /// Whether the text changes every second (otherwise only on minute boundaries).
    private(set) var hasSeconds = false

    init() { rebuild() }

    func rebuild(system: SystemClockPrefs = .read()) {
        // The "current" locale carries the user's 24-hour override, which macOS applies even to fixed
        // patterns. Following the system that's what we want; for a custom hour cycle, use a fresh
        // locale with the same language/region but without the override.
        let loc: Locale = Prefs.followSystem ? .autoupdatingCurrent : Locale(identifier: Locale.current.identifier)
        zone = Prefs.customTimeZone ?? .autoupdatingCurrent
        for f in [timeF, dateF, zoneF] { f.locale = loc; f.timeZone = zone }
        zoneStyle = Prefs.showZone ? Prefs.zoneStyle : nil
        switch zoneStyle {
        case .abbreviation: zoneF.dateFormat = "zzz"        // SGT, PST, GMT+8
        case .city: zoneF.dateFormat = "VVV"                // Singapore, 东京 (localized exemplar city)
        case .fullName: zoneF.dateFormat = "zzzz"           // Singapore Standard Time
        case .offset, nil: break                            // computed per date (DST)
        }

        let is24 = Prefs.followSystem ? system.is24Hour : Prefs.hourCycle == .h24
        let seconds = Prefs.followSystem ? system.seconds : Prefs.seconds
        let ampm = Prefs.followSystem ? system.ampm : Prefs.ampm
        var tpl = is24 ? "HHmm" : (ampm ? "hmma" : "hmm")
        hasSeconds = seconds
        if seconds { tpl += "ss" }
        var pattern = DateFormatter.dateFormat(fromTemplate: tpl, options: 0, locale: loc) ?? "HH:mm"
        if !is24 {
            pattern = pattern.replacingOccurrences(of: "H", with: "h")
            // Some locales (e.g. zh) use a flexible day period "B" (早上/下午) instead of AM/PM.
            for p in ["B", "b"] { pattern = pattern.replacingOccurrences(of: p, with: "") }
            if !ampm { pattern = pattern.replacingOccurrences(of: "a", with: "") }
            else if !pattern.contains("a") { pattern += " a" }
            pattern = pattern.trimmingCharacters(in: .whitespaces)
        }
        timeF.dateFormat = pattern

        let wd = Prefs.weekday, dt = Prefs.date
        hasDate = wd || dt
        dateFirst = Prefs.dateFirst
        guard hasDate else { return }
        let style = Prefs.dateStyle
        if style == .system {
            let t = (wd ? "EEE" : "") + (dt ? "MMMd" : "")
            dateF.dateFormat = DateFormatter.dateFormat(fromTemplate: t, options: 0, locale: loc) ?? t
        } else {
            let p = style == .custom ? Prefs.datePattern : style.pattern!
            dateF.dateFormat = dt ? (wd ? "EEE " + p : p) : "EEE"
        }
    }

    func string(from date: Date) -> String {
        var t = timeF.string(from: date)
        if let z = zoneStyle { t += " " + (z == .offset ? Self.offset(zone, date) : zoneF.string(from: date)) }
        guard hasDate else { return t }
        let d = dateF.string(from: date)
        return dateFirst ? "\(d) \(t)" : "\(t) \(d)"
    }

    /// "UTC+8", "UTC−3:30", "UTC" — shorter and clearer than GMT+08:00.
    static func offset(_ tz: TimeZone, _ date: Date = Date()) -> String {
        let secs = tz.secondsFromGMT(for: date)
        guard secs != 0 else { return "UTC" }
        let h = abs(secs) / 3600, m = abs(secs) % 3600 / 60
        return "UTC" + (secs < 0 ? "−" : "+") + "\(h)" + (m > 0 ? String(format: ":%02d", m) : "")
    }

    /// How a zone looks in each name style, for pickers.
    static func zoneSample(_ style: ZoneStyle, _ tz: TimeZone) -> String {
        if style == .offset { return offset(tz) }
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.timeZone = tz
        f.dateFormat = [.abbreviation: "zzz", .city: "VVV", .fullName: "zzzz"][style]!
        return f.string(from: Date())
    }

    /// Example rendering of a date style, for pickers.
    static func sample(_ style: DateStyle, _ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        if let p = style.pattern { f.dateFormat = p } else if style == .system { f.setLocalizedDateFormatFromTemplate("MMMd") } else { return "Custom…" }
        return f.string(from: date)
    }
}
