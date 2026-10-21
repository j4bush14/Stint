import Foundation

/// How times are written throughout the app.
enum TimeFormat {
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }

    /// The two halves of the clock for flip cards: minutes and seconds, or hours and
    /// minutes once an hour or more is left.
    static func clockParts(_ seconds: TimeInterval) -> (leading: String, trailing: String) {
        let s = max(0, Int(seconds.rounded(.up)))
        return s >= 3600
            ? (String(s / 3600), String(format: "%02d", (s % 3600) / 60))
            : (String(format: "%02d", s / 60), String(format: "%02d", s % 60))
    }

    static func hoursMinutes(_ seconds: TimeInterval) -> String {
        let m = Int(seconds / 60)
        if m < 60 { return "\(m) min" }
        return "\(m / 60) hr \(m % 60) min"
    }
}
