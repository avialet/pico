import Foundation

/// Sous-ensemble de RRULE suffisant pour une todo :
/// `FREQ=DAILY|WEEKLY|MONTHLY|YEARLY;INTERVAL=n;BYDAY=MO,WE;BYMONTHDAY=15;BASIS=SCHEDULE|COMPLETION`
public struct RecurrenceRule: Hashable, Sendable, Codable {
    public enum Frequency: String, Sendable, Codable { case daily, weekly, monthly, yearly }
    /// `schedule` : la prochaine occurrence se calcule depuis la date prevue.
    /// `completion` : depuis le jour ou l'on a termine (ex. "tous les 3 jours apres").
    public enum Basis: String, Sendable, Codable { case schedule, completion }

    public var frequency: Frequency
    public var interval: Int
    /// 1 = dimanche ... 7 = samedi. Vide = meme jour de semaine que l'origine.
    public var weekdays: Set<Int>
    public var monthDay: Int?
    public var basis: Basis

    public init(frequency: Frequency, interval: Int = 1, weekdays: Set<Int> = [],
                monthDay: Int? = nil, basis: Basis = .schedule) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.weekdays = weekdays
        self.monthDay = monthDay
        self.basis = basis
    }

    private static let dayCodes = [1: "SU", 2: "MO", 3: "TU", 4: "WE", 5: "TH", 6: "FR", 7: "SA"]

    public init?(string: String) {
        var freq: Frequency?
        var interval = 1
        var weekdays = Set<Int>()
        var monthDay: Int?
        var basis = Basis.schedule
        for part in string.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2 else { return nil }
            switch kv[0].uppercased() {
            case "FREQ":
                guard let f = Frequency(rawValue: kv[1].lowercased()) else { return nil }
                freq = f
            case "INTERVAL":
                guard let n = Int(kv[1]), n >= 1 else { return nil }
                interval = n
            case "BYDAY":
                for code in kv[1].split(separator: ",") {
                    guard let d = Self.dayCodes.first(where: { $0.value == code.uppercased() })?.key else { return nil }
                    weekdays.insert(d)
                }
            case "BYMONTHDAY":
                guard let n = Int(kv[1]), (1...31).contains(n) else { return nil }
                monthDay = n
            case "BASIS":
                guard let b = Basis(rawValue: kv[1].lowercased()) else { return nil }
                basis = b
            default:
                return nil
            }
        }
        guard let freq else { return nil }
        self.init(frequency: freq, interval: interval, weekdays: weekdays, monthDay: monthDay, basis: basis)
    }

    public var string: String {
        var parts = ["FREQ=\(frequency.rawValue.uppercased())"]
        if interval > 1 { parts.append("INTERVAL=\(interval)") }
        if !weekdays.isEmpty {
            parts.append("BYDAY=" + weekdays.sorted().compactMap { Self.dayCodes[$0] }.joined(separator: ","))
        }
        if let monthDay { parts.append("BYMONTHDAY=\(monthDay)") }
        if basis == .completion { parts.append("BASIS=COMPLETION") }
        return parts.joined(separator: ";")
    }

    /// Premiere occurrence strictement posterieure a `date`.
    public func nextDate(after date: DayDate) -> DayDate {
        switch frequency {
        case .daily:
            return date.adding(days: interval)
        case .weekly:
            guard !weekdays.isEmpty else { return date.adding(days: 7 * interval) }
            let anchorWeek = date.startOfWeek
            var candidate = date.adding(days: 1)
            for _ in 0..<(7 * interval + 7) {
                let weeksApart = anchorWeek.days(until: candidate.startOfWeek) / 7
                if weeksApart % interval == 0, weekdays.contains(candidate.weekday) {
                    return candidate
                }
                candidate = candidate.adding(days: 1)
            }
            return date.adding(days: 7 * interval)
        case .monthly:
            let wanted = monthDay ?? date.day
            var target = DayDate(year: date.year, month: date.month, day: 1).adding(months: interval)
            if wanted > date.day, monthDay != nil {
                // Le jour voulu est encore a venir dans le mois courant.
                let thisMonth = DayDate(year: date.year, month: date.month, day: 1)
                let clamped = min(wanted, thisMonth.daysInMonth)
                if clamped > date.day { return DayDate(year: date.year, month: date.month, day: clamped) }
            }
            target = DayDate(year: target.year, month: target.month, day: min(wanted, target.daysInMonth))
            return target
        case .yearly:
            let next = DayDate(year: date.year + interval, month: date.month, day: 1)
            return DayDate(year: next.year, month: next.month, day: min(date.day, next.daysInMonth))
        }
    }

    /// Occurrence suivante apres achevement : depuis la date prevue (schedule)
    /// ou depuis aujourd'hui (completion). En mode schedule, on avance jusqu'a
    /// un jour >= aujourd'hui pour ne pas recreer une tache deja en retard.
    public func nextOccurrence(plannedDate: DayDate?, completedOn today: DayDate) -> DayDate {
        switch basis {
        case .completion:
            return nextDate(after: today)
        case .schedule:
            var next = nextDate(after: plannedDate ?? today)
            var guardCount = 0
            while next < today, guardCount < 10_000 {
                next = nextDate(after: next)
                guardCount += 1
            }
            return next
        }
    }
}
