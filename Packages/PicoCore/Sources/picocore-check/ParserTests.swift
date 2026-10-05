import Foundation
import PicoCore

// Lundi 5 octobre 2026.
private let monday = DayDate(year: 2026, month: 10, day: 5)
private let infra = EntityID("p-infra")
private let vitrine = EntityID("p-vitrine")
private let parser = QuickEntryParser(today: monday, projects: [(infra, "Infra"), (vitrine, "Site vitrine refonte")])

private func p(_ s: String) -> ParsedEntry { parser.parse(s) }

let parserTests: (String, [Test]) = ("QuickEntryParser", [
    Test("plainTitle") {
        let e = p("Appeler le fournisseur")
        expectEqual(e.title, "Appeler le fournisseur")
        expect(e.plannedDate == nil && e.dueDate == nil && e.recurrence == nil)
    },
    Test("relativeDays") {
        expectEqual(p("x aujourd'hui").plannedDate, monday)
        expectEqual(p("x today").plannedDate, monday)
        expectEqual(p("x demain").plannedDate, monday.adding(days: 1))
        expectEqual(p("x tomorrow").plannedDate, monday.adding(days: 1))
        expectEqual(p("x après-demain").plannedDate, monday.adding(days: 2))
        expectEqual(p("x apres demain").plannedDate, monday.adding(days: 2))
        expectEqual(p("Relancer demain").title, "Relancer")
    },
    Test("inNDays") {
        expectEqual(p("x dans 3 jours").plannedDate, monday.adding(days: 3))
        expectEqual(p("x in 2 weeks").plannedDate, monday.adding(days: 14))
        expectEqual(p("x dans 1 mois").plannedDate, monday.adding(months: 1))
        expectEqual(p("x dans 3 jours").title, "x")
    },
    Test("weekdays") {
        expectEqual(p("x vendredi").plannedDate, DayDate(year: 2026, month: 10, day: 9))
        expectEqual(p("x friday").plannedDate, DayDate(year: 2026, month: 10, day: 9))
        expectEqual(p("x lundi").plannedDate, monday, "lundi = aujourd'hui si on est lundi")
        expectEqual(p("x dimanche").plannedDate, DayDate(year: 2026, month: 10, day: 11))
        expectEqual(p("x lundi prochain").plannedDate, DayDate(year: 2026, month: 10, day: 12))
        expectEqual(p("x next friday").plannedDate, DayDate(year: 2026, month: 10, day: 16))
        expectEqual(p("x le mercredi").title, "x")
        expectEqual(p("x ce week-end").plannedDate, DayDate(year: 2026, month: 10, day: 10))
        expectEqual(p("Aller a la mer").title, "Aller a la mer", "abreviations non reconnues")
        expectEqual(p("Aller a la mer").plannedDate, nil)
    },
    Test("numericDates") {
        expectEqual(p("x 12/10").plannedDate, DayDate(year: 2026, month: 10, day: 12))
        expectEqual(p("x 01/03").plannedDate, DayDate(year: 2027, month: 3, day: 1), "date passee -> annee suivante")
        expectEqual(p("x 25/12/2027").plannedDate, DayDate(year: 2027, month: 12, day: 25))
        expectEqual(p("x 2026-11-02").plannedDate, DayDate(year: 2026, month: 11, day: 2))
        expectEqual(p("x 12 oct").plannedDate, DayDate(year: 2026, month: 10, day: 12))
        expectEqual(p("x 1er novembre").plannedDate, DayDate(year: 2026, month: 11, day: 1))
        expectEqual(p("x oct 20").plannedDate, DayDate(year: 2026, month: 10, day: 20))
        expectEqual(p("x 15 janvier 2028").plannedDate, DayDate(year: 2028, month: 1, day: 15))
        expectEqual(p("x 32/10").plannedDate, nil)
        expectEqual(p("ticket 48213").title, "ticket 48213", "nombres non dates conserves")
    },
    Test("times") {
        expectEqual(p("x 14h").plannedTime, 14 * 60)
        expectEqual(p("x à 14h30").plannedTime, 14 * 60 + 30)
        expectEqual(p("x 9:15").plannedTime, 9 * 60 + 15)
        expectEqual(p("x at 2pm").plannedTime, 14 * 60)
        expectEqual(p("x 2:30pm").plannedTime, 14 * 60 + 30)
        expectEqual(p("x 12am").plannedTime, 0)
        expectEqual(p("x 14h").plannedDate, monday, "une heure sans date = aujourd'hui")
        expectEqual(p("x demain 14h").plannedDate, monday.adding(days: 1))
        expectEqual(p("x à 14h30").title, "x")
    },
    Test("evening") {
        let e = p("Lire ce soir")
        expectEqual(e.plannedSlot, .evening)
        expectEqual(e.plannedDate, monday)
        expectEqual(e.title, "Lire")
        expectEqual(p("Lire demain soir").plannedDate, monday.adding(days: 1))
        expectEqual(p("Lire demain soir").plannedSlot, .evening)
    },
    Test("dueDates") {
        let e = p("Rendre le rapport pour vendredi")
        expectEqual(e.dueDate, DayDate(year: 2026, month: 10, day: 9))
        expectEqual(e.plannedDate, nil)
        expectEqual(e.title, "Rendre le rapport")
        expectEqual(p("x due 12/10").dueDate, DayDate(year: 2026, month: 10, day: 12))
        expectEqual(p("x deadline tomorrow").dueDate, monday.adding(days: 1))
        expectEqual(p("x échéance 20 oct").dueDate, DayDate(year: 2026, month: 10, day: 20))
        expectEqual(p("x avant le 20 oct").dueDate, DayDate(year: 2026, month: 10, day: 20))
        let both = p("x demain pour vendredi")
        expectEqual(both.plannedDate, monday.adding(days: 1))
        expectEqual(both.dueDate, DayDate(year: 2026, month: 10, day: 9))
    },
    Test("recurrence") {
        expectEqual(p("x chaque jour").recurrence, RecurrenceRule(frequency: .daily))
        expectEqual(p("x tous les jours").recurrence, RecurrenceRule(frequency: .daily))
        expectEqual(p("x every day").recurrence, RecurrenceRule(frequency: .daily))
        expectEqual(p("x daily").recurrence, RecurrenceRule(frequency: .daily))
        expectEqual(p("x chaque semaine").recurrence, RecurrenceRule(frequency: .weekly))
        expectEqual(p("x toutes les 2 semaines").recurrence, RecurrenceRule(frequency: .weekly, interval: 2))
        expectEqual(p("x every 3 months").recurrence, RecurrenceRule(frequency: .monthly, interval: 3))
        expectEqual(p("x chaque année").recurrence, RecurrenceRule(frequency: .yearly))
        expectEqual(p("x tous les lundis").recurrence, RecurrenceRule(frequency: .weekly, weekdays: [2]))
        expectEqual(p("x every monday").recurrence, RecurrenceRule(frequency: .weekly, weekdays: [2]))
        expectEqual(p("x tous les lundis et jeudis").recurrence, RecurrenceRule(frequency: .weekly, weekdays: [2]), "un seul jour par motif")
        expectEqual(p("x jours ouvrés").recurrence, RecurrenceRule(frequency: .weekly, weekdays: [2, 3, 4, 5, 6]))
        expectEqual(p("x tous les 3 jours après achèvement").recurrence, RecurrenceRule(frequency: .daily, interval: 3, basis: .completion))
        expectEqual(p("x tous les lundis").title, "x")
        expectEqual(p("x tous les lundis").plannedDate, nil, "la recurrence ne fixe pas de date")
    },
    Test("projectAndTags") {
        let e = p("Corriger le login #Infra @urgent @bureau")
        expectEqual(e.title, "Corriger le login")
        expectEqual(e.projectName, "Infra")
        expectEqual(e.projectId, infra)
        expectEqual(e.tagNames, ["urgent", "bureau"])
        expectEqual(p("x #site").projectId, vitrine, "prefixe insensible a la casse")
        expectEqual(p("x #\"Site vitrine refonte\"").projectId, vitrine)
        expectEqual(p("x #Inconnu").projectId, nil)
        expectEqual(p("x #Inconnu").projectName, "Inconnu")
        expectEqual(p("Ticket PROJ#12").title, "Ticket PROJ#12", "# au milieu d'un mot conserve")
    },
    Test("priorityAndDuration") {
        expectEqual(p("x !").priority, 2)
        expectEqual(p("x !!").priority, 3)
        expectEqual(p("x !!!").priority, 3)
        expectEqual(p("Super !").title, "Super")
        expectEqual(p("x ~30m").durationMinutes, 30)
        expectEqual(p("x ~45 min").durationMinutes, 45)
        expectEqual(p("x ~1h").durationMinutes, 60)
        expectEqual(p("x ~1h30").durationMinutes, 90)
        expectEqual(p("x ~1h30 !!").title, "x")
    },
    Test("someday") {
        let e = p("Apprendre le piano un jour")
        expect(e.isSomeday)
        expectEqual(e.title, "Apprendre le piano")
        expect(p("x someday").isSomeday)
    },
    Test("fullLine") {
        let e = p("Relancer le fournisseur demain 14h #Infra @urgent !! ~30m tous les lundis pour vendredi")
        expectEqual(e.title, "Relancer le fournisseur")
        expectEqual(e.plannedDate, monday.adding(days: 1))
        expectEqual(e.plannedTime, 14 * 60)
        expectEqual(e.projectId, infra)
        expectEqual(e.tagNames, ["urgent"])
        expectEqual(e.priority, 3)
        expectEqual(e.durationMinutes, 30)
        expectEqual(e.recurrence, RecurrenceRule(frequency: .weekly, weekdays: [2]))
        expectEqual(e.dueDate, DayDate(year: 2026, month: 10, day: 9))
        expectEqual(e.highlights.count, 8)
        expect(e.highlights.map(\.range.lowerBound) == e.highlights.map(\.range.lowerBound).sorted())
        let todo = e.makeTodo()
        expectEqual(todo.title, "Relancer le fournisseur")
        expect(!todo.isInbox)
        expectEqual(todo.recurrenceRule, "FREQ=WEEKLY;BYDAY=MO")
    },
    Test("makeTodoInbox") {
        let todo = p("Juste une idee").makeTodo()
        expect(todo.isInbox)
        expectEqual(todo.status, .open)
    },
])
