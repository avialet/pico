import Foundation
import GRDB

/// Date calendaire sans heure ni fuseau (YYYY-MM-DD). Toute la planification
/// (prevu, echeance, recurrence) raisonne en jours, jamais en instants.
public struct DayDate: Hashable, Sendable, Codable, Comparable, CustomStringConvertible,
                       DatabaseValueConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Calendrier gregorien en UTC : l'arithmetique sur des jours ne depend
    /// d'aucun fuseau tant que l'aller et le retour utilisent le meme.
    static let utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2 // lundi
        return c
    }()

    public init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }

    /// Jour local d'un instant, selon le calendrier de l'utilisateur.
    public init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    public static func today(calendar: Calendar = .current) -> DayDate {
        DayDate(Date(), calendar: calendar)
    }

    /// "2026-10-05"
    public init?(isoString: String) {
        let parts = isoString.split(separator: "-")
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
    public var description: String { isoString }

    // MARK: Arithmetique

    var utcDate: Date {
        Self.utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public func adding(days: Int) -> DayDate {
        DayDate(Self.utcCalendar.date(byAdding: .day, value: days, to: utcDate)!, calendar: Self.utcCalendar)
    }
    public func adding(months: Int) -> DayDate {
        DayDate(Self.utcCalendar.date(byAdding: .month, value: months, to: utcDate)!, calendar: Self.utcCalendar)
    }
    public func adding(years: Int) -> DayDate {
        DayDate(Self.utcCalendar.date(byAdding: .year, value: years, to: utcDate)!, calendar: Self.utcCalendar)
    }
    public func days(until other: DayDate) -> Int {
        Self.utcCalendar.dateComponents([.day], from: utcDate, to: other.utcDate).day!
    }
    /// 1 = dimanche ... 7 = samedi (convention Foundation).
    public var weekday: Int { Self.utcCalendar.component(.weekday, from: utcDate) }
    public var daysInMonth: Int { Self.utcCalendar.range(of: .day, in: .month, for: utcDate)!.count }
    /// Lundi de la semaine.
    public var startOfWeek: DayDate {
        let offset = (weekday + 5) % 7 // lundi -> 0, dimanche -> 6
        return adding(days: -offset)
    }
    /// Instant local a une heure donnee (minutes depuis minuit), pour les rappels.
    public func date(atMinutes minutes: Int, calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day,
                                           hour: minutes / 60, minute: minutes % 60))!
    }

    public static func < (lhs: DayDate, rhs: DayDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // MARK: Codable / GRDB (texte ISO)

    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let d = DayDate(isoString: s) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "DayDate invalide: \(s)"))
        }
        self = d
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(isoString)
    }
    public var databaseValue: DatabaseValue { isoString.databaseValue }
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> DayDate? {
        String.fromDatabaseValue(dbValue).flatMap(DayDate.init(isoString:))
    }
}
