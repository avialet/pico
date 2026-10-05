import Foundation
import GRDB
import PicoCore

let oct5 = DayDate(year: 2026, month: 10, day: 5)

func makeServices() throws -> (AppDatabase, TodoService, ProjectService, TagService) {
    let db = try AppDatabase.inMemory()
    return (db, TodoService(db: db), ProjectService(db: db), TagService(db: db))
}

let todoServiceTests: (String, [Test]) = ("TodoService", [
    Test("createGoesToInbox") {
        let (_, todos, _, _) = try makeServices()
        let t = try todos.create(title: "  Appeler le fournisseur  ")
        expectEqual(t.title, "Appeler le fournisseur")
        expect(t.isInbox)
        expectEqual(try todos.inbox().map(\.id), [t.id])
        expectEqual(try todos.anytime().count, 0)
        expectThrows({ try todos.create(title: "   ") }, "titre vide")
    },
    Test("createInProjectIsNotInbox") {
        let (_, todos, projects, _) = try makeServices()
        let p = try projects.createProject("Infra")
        let a = try todos.create(title: "A", projectId: p.id)
        let b = try todos.create(title: "B", projectId: p.id)
        expect(!a.isInbox)
        expectEqual(try todos.inbox().count, 0)
        expectEqual(try todos.todos(inProject: p.id).map(\.title), ["A", "B"])
        expect(a.position < b.position)
    },
    Test("planTodayAndUpcoming") {
        let (_, todos, _, _) = try makeServices()
        let t1 = try todos.create(title: "Aujourd'hui")
        let t2 = try todos.create(title: "Demain")
        let t3 = try todos.create(title: "Hier")
        try todos.plan(t1.id, on: oct5)
        try todos.plan(t2.id, on: oct5.adding(days: 1))
        try todos.plan(t3.id, on: oct5.adding(days: -1))
        expectEqual(Set(try todos.today(oct5).map(\.id)), [t1.id, t3.id])
        expectEqual(try todos.upcoming(from: oct5).map(\.id), [t2.id])
        expectEqual(try todos.inbox().count, 0)
        try todos.plan(t1.id, on: nil)
        expectEqual(try todos.anytime().map(\.id), [t1.id])
    },
    Test("somedayAndBack") {
        let (_, todos, _, _) = try makeServices()
        let t = try todos.create(title: "Un jour")
        try todos.moveToSomeday(t.id)
        expectEqual(try todos.someday().map(\.id), [t.id])
        expectEqual(try todos.inbox().count, 0)
        try todos.plan(t.id, on: oct5)
        expectEqual(try todos.someday().count, 0)
        expectEqual(try todos.today(oct5).map(\.id), [t.id])
    },
    Test("completeAndLogbook") {
        let (_, todos, _, _) = try makeServices()
        let t = try todos.create(title: "Faire")
        let now = Date(timeIntervalSince1970: 1_000_000)
        let next = try todos.complete(t.id, today: oct5, now: now)
        expect(next == nil)
        let done = try todos.fetch(t.id)!
        expectEqual(done.status, .done)
        expectEqual(done.completedAt, now)
        expectEqual(try todos.inbox().count, 0)
        expectEqual(try todos.logbook().map(\.id), [t.id])
        try todos.reopen(t.id)
        expectEqual(try todos.fetch(t.id)!.status, .open)
        expect(try todos.complete(t.id) == nil, "deja terminee : pas d'effet")
    },
    Test("completeRecurringCreatesNext") {
        let (_, todos, _, tags) = try makeServices()
        var t = Todo(title: "Rapport hebdo", plannedDate: oct5, dueDate: oct5.adding(days: 2))
        t.recurrence = RecurrenceRule(frequency: .weekly)
        t = try todos.create(t)
        let tag = try tags.findOrCreate("bureau")
        try todos.setTags([tag.id], on: t.id)
        try todos.addChecklistItem("Chiffres", to: t.id)
        let next = try todos.complete(t.id, today: oct5)!
        expectEqual(next.plannedDate, oct5.adding(days: 7))
        expectEqual(next.dueDate, oct5.adding(days: 9), "l'ecart echeance/prevu est conserve")
        expectEqual(next.recurrenceParentId, t.id)
        expectEqual(next.status, .open)
        expectEqual(next.recurrenceRule, t.recurrenceRule)
        expectEqual(try todos.tags(of: next.id).map(\.name), ["bureau"])
        expectEqual(try todos.checklist(of: next.id).map(\.title), ["Chiffres"])
        expect(try todos.checklist(of: next.id).allSatisfy { !$0.isDone })
        let third = try todos.complete(next.id, today: oct5.adding(days: 7))!
        expectEqual(third.recurrenceParentId, t.id, "la racine est conservee")
    },
    Test("softDeleteHidesEverywhere") {
        let (db, todos, _, _) = try makeServices()
        let t = try todos.create(title: "Poubelle")
        try todos.delete(t.id)
        expect(try todos.fetch(t.id) == nil)
        expectEqual(try todos.inbox().count, 0)
        let raw = try db.read { db in try Todo.filter(key: t.id).fetchOne(db) }
        expect(raw?.deletedAt != nil, "la ligne reste avec deletedAt")
        expectThrows({ try todos.complete(t.id) })
    },
    Test("moveAndReorder") {
        let (_, todos, projects, _) = try makeServices()
        let p = try projects.createProject("P")
        let h = try projects.createHeading("Phase 1", in: p.id)
        let a = try todos.create(title: "a")
        let b = try todos.create(title: "b")
        try todos.move(a.id, toProject: p.id, heading: h.id)
        try todos.move(b.id, toProject: p.id, heading: h.id)
        expectEqual(try todos.todos(inProject: p.id).map(\.title), ["a", "b"])
        expect(!(try todos.fetch(a.id)!.isInbox))
        try todos.reorder([b.id, a.id])
        expectEqual(try todos.todos(inProject: p.id).map(\.title), ["b", "a"])
    },
    Test("search") {
        let (_, todos, _, _) = try makeServices()
        try todos.create(title: "Relancer le fournisseur", notes: "ticket 48213")
        try todos.create(title: "Autre")
        expectEqual(try todos.search("clara").count, 1)
        expectEqual(try todos.search("48213").count, 1)
        expectEqual(try todos.search("zzz").count, 0)
    },
    Test("upsertExternalDedup") {
        let (_, todos, _, _) = try makeServices()
        let a = try todos.upsertExternal(Todo(title: "PROJ-12 Bug login", source: "jira", externalKey: "PROJ-12", externalURL: "https://j/12"))
        let b = try todos.upsertExternal(Todo(title: "PROJ-12 Bug login (maj)", dueDate: oct5, source: "jira", externalKey: "PROJ-12"))
        expectEqual(a.id, b.id)
        expectEqual(try todos.inbox().count, 1)
        let stored = try todos.fetch(a.id)!
        expectEqual(stored.title, "PROJ-12 Bug login (maj)")
        expectEqual(stored.dueDate, oct5)
        try todos.upsertExternal(Todo(title: "Autre", source: "jira", externalKey: "PROJ-13"))
        expectEqual(try todos.inbox().count, 2)
    },
    Test("tagsSetAndReplace") {
        let (_, todos, _, tags) = try makeServices()
        let t = try todos.create(title: "x")
        let a = try tags.findOrCreate("Urgent")
        let b = try tags.findOrCreate("bureau")
        expectEqual(try tags.findOrCreate("urgent").id, a.id, "insensible a la casse")
        try todos.setTags([a.id, b.id], on: t.id)
        expectEqual(Set(try todos.tags(of: t.id).map(\.id)), [a.id, b.id])
        try todos.setTags([b.id], on: t.id)
        expectEqual(try todos.tags(of: t.id).map(\.id), [b.id])
        try todos.setTags([a.id, b.id], on: t.id)
        expectEqual(try todos.tags(of: t.id).count, 2, "re-ajout apres suppression douce")
        try tags.delete(a.id)
        expectEqual(try todos.tags(of: t.id).map(\.id), [b.id])
    },
    Test("checklist") {
        let (_, todos, _, _) = try makeServices()
        let t = try todos.create(title: "x")
        let i1 = try todos.addChecklistItem("un", to: t.id)
        try todos.addChecklistItem("deux", to: t.id)
        try todos.setChecklistItem(i1.id, done: true)
        let items = try todos.checklist(of: t.id)
        expectEqual(items.map(\.title), ["un", "deux"])
        expectEqual(items.map(\.isDone), [true, false])
    },
])

let projectServiceTests: (String, [Test]) = ("ProjectService", [
    Test("areasAndProjects") {
        let (_, _, projects, _) = try makeServices()
        let area = try projects.createArea("Travail")
        let p1 = try projects.createProject("Infra", areaId: area.id)
        let p2 = try projects.createProject("Perso")
        expectEqual(try projects.projects().map(\.id), [p1.id, p2.id])
        expectEqual(try projects.projects(inArea: area.id).map(\.id), [p1.id])
        expectEqual(try projects.projects(inArea: nil).map(\.id), [p2.id])
        try projects.deleteArea(area.id)
        expectEqual(try projects.areas().count, 0)
        expectEqual(try projects.project(p1.id)?.areaId, nil, "projet orphelin conserve")
    },
    Test("completeProjectCompletesTodos") {
        let (_, todos, projects, _) = try makeServices()
        let p = try projects.createProject("P")
        try todos.create(title: "a", projectId: p.id)
        try todos.create(title: "b", projectId: p.id)
        try todos.complete(try todos.todos(inProject: p.id)[0].id)
        expectEqual(try projects.progress(of: p.id).done, 1)
        try projects.completeProject(p.id)
        expectEqual(try projects.projects(status: .done).count, 1)
        expectEqual(try projects.projects().count, 0)
        expectEqual(try todos.todos(inProject: p.id).count, 0)
        expectEqual(try todos.todos(inProject: p.id, includeDone: true).count, 2)
    },
    Test("deleteProjectDeletesTodos") {
        let (_, todos, projects, _) = try makeServices()
        let p = try projects.createProject("P")
        let t = try todos.create(title: "a", projectId: p.id)
        try projects.deleteProject(p.id)
        expect(try projects.project(p.id) == nil)
        expect(try todos.fetch(t.id) == nil)
    },
    Test("headings") {
        let (_, todos, projects, _) = try makeServices()
        let p = try projects.createProject("P")
        let h = try projects.createHeading("H1", in: p.id)
        let t = try todos.create(Todo(projectId: p.id, headingId: h.id, title: "x"))
        expectEqual(try projects.headings(of: p.id).map(\.name), ["H1"])
        try projects.deleteHeading(h.id)
        expectEqual(try projects.headings(of: p.id).count, 0)
        expectEqual(try todos.fetch(t.id)?.headingId, nil)
    },
])

let changeLogTests: (String, [Test]) = ("ChangeLog", [
    Test("everyWriteIsLogged") {
        let (db, todos, _, _) = try makeServices()
        let t = try todos.create(title: "x")
        try todos.plan(t.id, on: oct5)
        try todos.delete(t.id)
        let entries = try db.read { db in
            try ChangeLogEntry.filter(Column("entityId") == t.id).order(Column("seq")).fetchAll(db)
        }
        expectEqual(entries.map(\.op), [.insert, .update, .delete])
        expectEqual(entries.map(\.entity), ["todo", "todo", "todo"])
        expect(entries.allSatisfy { $0.deviceId == db.deviceId })
        expect(entries[1].payload.contains("\"plannedDate\":\"2026-10-05\""), entries[1].payload)
        expect(entries.compactMap(\.seq) == entries.compactMap(\.seq).sorted())
    },
    Test("deviceIdPersists") {
        let db = try AppDatabase.inMemory()
        expect(db.deviceId.count == 36)
        expectEqual(db.deviceId, db.deviceId)
    },
    Test("openOnDisk") {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pico-test-\(UUID().uuidString)")
        let url = dir.appendingPathComponent("pico.sqlite")
        let db1 = try AppDatabase.open(at: url)
        let id = db1.deviceId
        try TodoService(db: db1).create(title: "persist")
        let db2 = try AppDatabase.open(at: url)
        expectEqual(db2.deviceId, id)
        expectEqual(try TodoService(db: db2).inbox().map(\.title), ["persist"])
        try? FileManager.default.removeItem(at: dir)
    },
])

let summaryTests: (String, [Test]) = ("Summaries", [
    Test("checklistAndTagIndex") {
        let (_, todos, projects, tags) = try makeServices()
        let p = try projects.createProject("P")
        let t = try todos.create(title: "x", projectId: p.id)
        let i = try todos.addChecklistItem("a", to: t.id)
        try todos.addChecklistItem("b", to: t.id)
        try todos.setChecklistItem(i.id, done: true)
        try todos.setTags([try tags.findOrCreate("bureau").id], on: t.id)
        expectEqual(try todos.checklistIndex()[t.id], Tally(done: 1, total: 2))
        expectEqual(try todos.tagIndex()[t.id]?.map(\.name), ["bureau"])
        try todos.create(title: "y", projectId: p.id)
        try todos.complete(t.id)
        expectEqual(try projects.progressIndex()[p.id], Tally(done: 1, total: 2))
    },
])
