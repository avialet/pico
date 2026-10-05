import Foundation
import PicoCore

extension DayDate {
    nonisolated(unsafe) static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE d MMM"
        return f
    }()
    nonisolated(unsafe) static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE"
        return f
    }()

    /// "Aujourd'hui", "Demain", "Hier", sinon "lun. 12 oct."
    func relativeLabel(today: DayDate = .today()) -> String {
        let delta = today.days(until: self)
        switch delta {
        case 0: return "Aujourd'hui"
        case 1: return "Demain"
        case -1: return "Hier"
        default: return Self.shortFormatter.string(from: date(atMinutes: 12 * 60)).capitalized
        }
    }

    var weekdayLabel: String {
        Self.weekdayFormatter.string(from: date(atMinutes: 12 * 60)).capitalized
    }

    var isPast: Bool { self < .today() }
}

extension Int {
    /// 90 -> "1 h 30", 45 -> "45 min"
    var durationLabel: String {
        let h = self / 60, m = self % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(String(format: "%02d", m))"
    }
    /// 14 * 60 + 30 -> "14:30"
    var timeLabel: String { String(format: "%d:%02d", self / 60, self % 60) }
}
