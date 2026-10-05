import Foundation
import PicoCore

let recurrenceTests: (String, [Test]) = ("Recurrence", [
    Test("parseAndFormat") {
        let r = RecurrenceRule(string: "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR;BASIS=COMPLETION")!
        expectEqual(r.frequency, .weekly)
        expectEqual(r.interval, 2)
        expectEqual(r.weekdays, [2, 6])
        expectEqual(r.basis, .completion)
        expectEqual(r.string, "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR;BASIS=COMPLETION")
        expectEqual(RecurrenceRule(frequency: .daily).string, "FREQ=DAILY")
        expect(RecurrenceRule(string: "FREQ=HOURLY") == nil)
        expect(RecurrenceRule(string: "BYDAY=MO") == nil, "FREQ obligatoire")
        expect(RecurrenceRule(string: "FREQ=DAILY;FOO=1") == nil)
    },
    Test("daily") {
        let monday = DayDate(year: 2026, month: 10, day: 5)
        expectEqual(RecurrenceRule(frequency: .daily).nextDate(after: monday).isoString, "2026-10-06")
        expectEqual(RecurrenceRule(frequency: .daily, interval: 3).nextDate(after: monday).isoString, "2026-10-08")
    },
    Test("weeklySameDay") {
        let monday = DayDate(year: 2026, month: 10, day: 5)
        expectEqual(RecurrenceRule(frequency: .weekly).nextDate(after: monday).isoString, "2026-10-12")
    },
    Test("weeklyByDay") {
        let monday = DayDate(year: 2026, month: 10, day: 5)
        let rule = RecurrenceRule(frequency: .weekly, weekdays: [2, 4]) // lundi, mercredi
        let wed = rule.nextDate(after: monday)
        expectEqual(wed.isoString, "2026-10-07")
        expectEqual(rule.nextDate(after: wed).isoString, "2026-10-12")
    },
    Test("weeklyByDayInterval2") {
        let monday = DayDate(year: 2026, month: 10, day: 5)
        let rule = RecurrenceRule(frequency: .weekly, interval: 2, weekdays: [2, 4])
        expectEqual(rule.nextDate(after: monday).isoString, "2026-10-07", "mercredi de la meme semaine")
        expectEqual(rule.nextDate(after: DayDate(year: 2026, month: 10, day: 7)).isoString, "2026-10-19", "saute une semaine")
    },
    Test("monthly") {
        let d = DayDate(year: 2026, month: 1, day: 31)
        expectEqual(RecurrenceRule(frequency: .monthly).nextDate(after: d).isoString, "2026-02-28")
        let the15 = RecurrenceRule(frequency: .monthly, monthDay: 15)
        expectEqual(the15.nextDate(after: DayDate(year: 2026, month: 10, day: 5)).isoString, "2026-10-15")
        expectEqual(the15.nextDate(after: DayDate(year: 2026, month: 10, day: 15)).isoString, "2026-11-15")
        expectEqual(the15.nextDate(after: DayDate(year: 2026, month: 10, day: 20)).isoString, "2026-11-15")
    },
    Test("yearly") {
        expectEqual(RecurrenceRule(frequency: .yearly).nextDate(after: DayDate(year: 2024, month: 2, day: 29)).isoString, "2025-02-28")
    },
    Test("nextOccurrenceScheduleSkipsPast") {
        let rule = RecurrenceRule(frequency: .daily)
        let planned = DayDate(year: 2026, month: 10, day: 1)
        let today = DayDate(year: 2026, month: 10, day: 5)
        expectEqual(rule.nextOccurrence(plannedDate: planned, completedOn: today).isoString, "2026-10-05")
        let weekly = RecurrenceRule(frequency: .weekly)
        expectEqual(weekly.nextOccurrence(plannedDate: planned, completedOn: today).isoString, "2026-10-08")
    },
    Test("nextOccurrenceCompletionBasis") {
        let rule = RecurrenceRule(frequency: .daily, interval: 3, basis: .completion)
        let today = DayDate(year: 2026, month: 10, day: 5)
        expectEqual(rule.nextOccurrence(plannedDate: DayDate(year: 2026, month: 9, day: 1), completedOn: today).isoString, "2026-10-08")
    },
])
