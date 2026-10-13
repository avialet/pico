import Foundation
import PicoCore

private func frenchFormatter(_ format: String) -> DateFormatter {
    let f = DateFormatter()
    f.locale = Locale(identifier: "fr_FR")
    f.dateFormat = format
    return f
}

extension DayDate {
    static let shortFormatter = frenchFormatter("EEE d MMM")
    static let weekdayFormatter = frenchFormatter("EEEE")
    static let longFormatter = frenchFormatter("EEEE d MMMM")
    static let monthFormatter = frenchFormatter("MMMM yyyy")

    private var noon: Date { date(atMinutes: 12 * 60) }

    /// "Aujourd'hui", "Demain", "Hier", sinon "lun. 12 oct."
    func relativeLabel(today: DayDate = .today()) -> String {
        switch today.days(until: self) {
        case 0: "Aujourd'hui"
        case 1: "Demain"
        case -1: "Hier"
        default: Self.shortFormatter.string(from: noon).capitalizedFirst
        }
    }

    var weekdayLabel: String { Self.weekdayFormatter.string(from: noon).capitalizedFirst }
    var longLabel: String { Self.longFormatter.string(from: noon).capitalizedFirst }
    var monthLabel: String { Self.monthFormatter.string(from: noon).capitalizedFirst }
    var isPast: Bool { self < .today() }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

extension Int {
    /// 90 -> "1 h 30", 45 -> "45 min"
    var durationLabel: String {
        let h = self / 60, m = self % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(String(format: "%02d", m))"
    }

    /// 870 -> "14:30"
    var timeLabel: String { String(format: "%d:%02d", self / 60, self % 60) }
}

extension RecurrenceRule {
    private static let dayNames = [1: "dim.", 2: "lun.", 3: "mar.", 4: "mer.", 5: "jeu.", 6: "ven.", 7: "sam."]

    /// "Chaque lun., jeu.", "Tous les 3 jours après achèvement"...
    var label: String {
        var base: String
        switch frequency {
        case .daily:
            base = interval == 1 ? "Chaque jour" : "Tous les \(interval) jours"
        case .weekly:
            if weekdays == [2, 3, 4, 5, 6] {
                base = "Jours ouvrés"
            } else if !weekdays.isEmpty {
                let days = weekdays.sorted { ($0 + 5) % 7 < ($1 + 5) % 7 }.compactMap { Self.dayNames[$0] }
                base = (interval == 1 ? "Chaque " : "Toutes les \(interval) sem. le ") + days.joined(separator: ", ")
            } else {
                base = interval == 1 ? "Chaque semaine" : "Toutes les \(interval) semaines"
            }
        case .monthly:
            base = interval == 1 ? "Chaque mois" : "Tous les \(interval) mois"
            if let d = monthDay { base += " le \(d)" }
        case .yearly:
            base = interval == 1 ? "Chaque année" : "Tous les \(interval) ans"
        }
        if basis == .completion { base += " après achèvement" }
        return base
    }
}
