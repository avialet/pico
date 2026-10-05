import Foundation
import PicoCore

let dayDateTests: (String, [Test]) = ("DayDate", [
    Test("isoRoundTrip") {
        let d = DayDate(isoString: "2026-10-05")!
        expectEqual(d.isoString, "2026-10-05")
        expect(DayDate(isoString: "2026-13-01") == nil)
        expect(DayDate(isoString: "oops") == nil)
    },
    Test("arithmetic") {
        let d = DayDate(year: 2026, month: 10, day: 5)
        expectEqual(d.adding(days: 27).isoString, "2026-11-01")
        expectEqual(d.adding(months: 1).isoString, "2026-11-05")
        expectEqual(DayDate(year: 2026, month: 1, day: 31).adding(months: 1).isoString, "2026-02-28")
        expectEqual(d.days(until: d.adding(days: 10)), 10)
        expectEqual(d.weekday, 2, "5 oct 2026 est un lundi")
        expectEqual(d.startOfWeek, d)
        expectEqual(DayDate(year: 2026, month: 10, day: 11).startOfWeek, d, "dimanche -> lundi")
        expectEqual(DayDate(year: 2024, month: 2, day: 1).daysInMonth, 29)
    },
    Test("comparison") {
        expect(DayDate(year: 2026, month: 1, day: 31) < DayDate(year: 2026, month: 2, day: 1))
        expect(DayDate(year: 2025, month: 12, day: 31) < DayDate(year: 2026, month: 1, day: 1))
    },
    Test("fromLocalDate") {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Paris")!
        // 2026-10-05 23:30 Paris = 21:30 UTC
        let date = cal.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 23, minute: 30))!
        expectEqual(DayDate(date, calendar: cal).isoString, "2026-10-05")
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        expectEqual(DayDate(date, calendar: utc).isoString, "2026-10-05")
    },
])
