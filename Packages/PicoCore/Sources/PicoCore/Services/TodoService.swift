import Foundation
import GRDB

public extension Todo {
    /// Lignes non supprimees.
    static var live: QueryInterfaceRequest<Todo> {
        Todo.filter(Column("deletedAt") == nil)
    }
    static var open: QueryInterfaceRequest<Todo> {
        live.filter(Column("status") == TodoStatus.open.rawValue)
    }
}

public enum PicoError: Error, Equatable {
    case notFound(EntityID)
    case invalidTitle
}

/// Toutes les operations sur les taches. Chaque ecriture est journalisee.
public struct TodoService: Sendable {
    public let db: AppDatabase
    public init(db: AppDatabase) { self.db = db }

    // MARK: Creation / edition

    /// Insere la tache en fin de son conteneur (projet, heading ou inbox).
    @discardableResult
    public func create(_ todo: Todo) throws -> Todo {
        let title = todo.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw PicoError.invalidTitle }
        var todo = todo
        todo.title = title
        return try db.write { db in
            todo.position = try Self.nextPosition(db, projectId: todo.projectId, headingId: todo.headingId)
            try db.insertLogged(todo)
            return todo
        }
    }

    @discardableResult
    public func create(title: String, projectId: EntityID? = nil, plannedDate: DayDate? = nil,
                       dueDate: DayDate? = nil, notes: String = "", now: Date = Date()) throws -> Todo {
        try create(Todo(projectId: projectId, title: title, notes: notes,
                        plannedDate: plannedDate, dueDate: dueDate, now: now))
    }

    /// Sauvegarde une tache modifiee. Recalcule l'appartenance a l'inbox.
    public func save(_ todo: Todo, now: Date = Date()) throws {
        var todo = todo
        if todo.projectId != nil || todo.plannedDate != nil || todo.isSomeday { todo.isInbox = false }
        try db.write { db in try db.updateLogged(&todo, now: now) }
    }

    public func fetch(_ id: EntityID) throws -> Todo? {
        try db.read { db in try Todo.live.filter(key: id).fetchOne(db) }
    }

    private func require(_ id: EntityID, _ db: Database) throws -> Todo {
        guard let todo = try Todo.live.filter(key: id).fetchOne(db) else { throw PicoError.notFound(id) }
        return todo
    }

    // MARK: Statut

    /// Termine la tache. Si elle est recurrente, cree et renvoie l'occurrence suivante.
    @discardableResult
    public func complete(_ id: EntityID, today: DayDate = .today(), now: Date = Date()) throws -> Todo? {
        try db.write { db in
            var todo = try require(id, db)
            guard todo.status == .open else { return nil }
            todo.status = .done
            todo.completedAt = now
            try db.updateLogged(&todo, now: now)

            guard let rule = todo.recurrence else { return nil }
            let nextDate = rule.nextOccurrence(plannedDate: todo.plannedDate, completedOn: today)
            var next = todo
            next.id = .new()
            next.status = .open
            next.completedAt = nil
            next.createdAt = now
            next.updatedAt = now
            next.recurrenceParentId = todo.recurrenceParentId ?? todo.id
            next.plannedDate = nextDate
            if let due = todo.dueDate, let planned = todo.plannedDate {
                next.dueDate = nextDate.adding(days: planned.days(until: due))
            } else if todo.dueDate != nil {
                next.dueDate = nextDate
            }
            next.isInbox = false
            next.position = try Self.nextPosition(db, projectId: next.projectId, headingId: next.headingId)
            try db.insertLogged(next)
            try Self.copyTags(db, from: todo.id, to: next.id, now: now)
            try Self.copyChecklist(db, from: todo.id, to: next.id, now: now)
            return next
        }
    }

    public func reopen(_ id: EntityID, now: Date = Date()) throws {
        try db.write { db in
            var todo = try require(id, db)
            todo.status = .open
            todo.completedAt = nil
            try db.updateLogged(&todo, now: now)
        }
    }

    public func cancel(_ id: EntityID, now: Date = Date()) throws {
        try db.write { db in
            var todo = try require(id, db)
            todo.status = .cancelled
            todo.completedAt = now
            try db.updateLogged(&todo, now: now)
        }
    }

    public func delete(_ id: EntityID, now: Date = Date()) throws {
        try db.write { db in
            var todo = try require(id, db)
            try db.softDeleteLogged(&todo, now: now)
        }
    }

    // MARK: Planification

    /// Prevoit la tache un jour donne (nil = A tout moment).
    public func plan(_ id: EntityID, on date: DayDate?, slot: PlannedSlot = .day, now: Date = Date()) throws {
        try db.write { db in
            var todo = try require(id, db)
            todo.plannedDate = date
            todo.plannedSlot = slot
            todo.isSomeday = false
            todo.isInbox = false
            try db.updateLogged(&todo, now: now)
        }
    }

    public func moveToSomeday(_ id: EntityID, now: Date = Date()) throws {
        try db.write { db in
            var todo = try require(id, db)
            todo.plannedDate = nil
            todo.isSomeday = true
            todo.isInbox = false
            try db.updateLogged(&todo, now: now)
        }
    }

    public func move(_ id: EntityID, toProject projectId: EntityID?, heading headingId: EntityID? = nil,
                     now: Date = Date()) throws {
        try db.write { db in
            var todo = try require(id, db)
            todo.projectId = projectId
            todo.headingId = headingId
            if projectId != nil { todo.isInbox = false }
            todo.position = try Self.nextPosition(db, projectId: projectId, headingId: headingId)
            try db.updateLogged(&todo, now: now)
        }
    }

    /// Reordonne : positions 1...n dans l'ordre donne.
    public func reorder(_ ids: [EntityID], now: Date = Date()) throws {
        try db.write { db in
            for (index, id) in ids.enumerated() {
                var todo = try require(id, db)
                todo.position = Double(index + 1)
                try db.updateLogged(&todo, now: now)
            }
        }
    }

    // MARK: Listes

    public func inbox() throws -> [Todo] {
        try db.read { db in
            try Todo.open.filter(Column("isInbox") == true).order(Column("position")).fetchAll(db)
        }
    }

    /// Taches prevues aujourd'hui ou avant (les "hier non fait" ont plannedDate < today).
    public func today(_ today: DayDate = .today()) throws -> [Todo] {
        try db.read { db in
            try Todo.open.filter(Column("plannedDate") <= today.isoString)
                .order(Column("plannedSlot"), Column("plannedTime"), Column("position")).fetchAll(db)
        }
    }

    /// Taches prevues strictement apres `today`, dans la fenetre demandee.
    public func upcoming(from today: DayDate = .today(), days: Int = 30) throws -> [Todo] {
        let end = today.adding(days: days)
        return try db.read { db in
            try Todo.open.filter(Column("plannedDate") > today.isoString && Column("plannedDate") <= end.isoString)
                .order(Column("plannedDate"), Column("plannedSlot"), Column("position")).fetchAll(db)
        }
    }

    public func anytime() throws -> [Todo] {
        try db.read { db in
            try Todo.open.filter(Column("isInbox") == false && Column("isSomeday") == false
                                 && Column("plannedDate") == nil)
                .order(Column("position")).fetchAll(db)
        }
    }

    public func someday() throws -> [Todo] {
        try db.read { db in
            try Todo.open.filter(Column("isSomeday") == true).order(Column("position")).fetchAll(db)
        }
    }

    public func logbook(limit: Int = 200) throws -> [Todo] {
        try db.read { db in
            try Todo.live.filter(Column("status") != TodoStatus.open.rawValue)
                .order(Column("completedAt").desc).limit(limit).fetchAll(db)
        }
    }

    public func todos(inProject projectId: EntityID, includeDone: Bool = false) throws -> [Todo] {
        try db.read { db in
            let base = includeDone ? Todo.live : Todo.open
            return try base.filter(Column("projectId") == projectId).order(Column("position")).fetchAll(db)
        }
    }

    public func search(_ text: String, limit: Int = 50) throws -> [Todo] {
        let pattern = "%" + text.replacingOccurrences(of: "%", with: "\\%") + "%"
        return try db.read { db in
            try Todo.live.filter(Column("title").like(pattern) || Column("notes").like(pattern))
                .order(Column("status"), Column("updatedAt").desc).limit(limit).fetchAll(db)
        }
    }

    /// Tache venant d'un systeme externe : met a jour si (source, externalKey) existe deja.
    @discardableResult
    public func upsertExternal(_ incoming: Todo, now: Date = Date()) throws -> Todo {
        guard let source = incoming.source, let key = incoming.externalKey else { return try create(incoming) }
        let existing = try db.read { db in
            try Todo.live.filter(Column("source") == source && Column("externalKey") == key).fetchOne(db)
        }
        guard var existing else { return try create(incoming) }
        existing.title = incoming.title
        existing.notes = incoming.notes
        existing.externalURL = incoming.externalURL
        if let due = incoming.dueDate { existing.dueDate = due }
        if incoming.priority != 0 { existing.priority = incoming.priority }
        try db.write { db in try db.updateLogged(&existing, now: now) }
        return existing
    }

    // MARK: Tags

    public func setTags(_ tagIds: [EntityID], on todoId: EntityID, now: Date = Date()) throws {
        try db.write { db in
            let current = try TodoTag.filter(Column("todoId") == todoId && Column("deletedAt") == nil).fetchAll(db)
            for var link in current where !tagIds.contains(link.tagId) {
                try db.softDeleteLogged(&link, now: now)
            }
            let currentIds = Set(current.map(\.tagId))
            for tagId in tagIds where !currentIds.contains(tagId) {
                try db.execute(sql: "DELETE FROM todoTag WHERE todoId = ? AND tagId = ?", arguments: [todoId, tagId])
                try db.insertLogged(TodoTag(todoId: todoId, tagId: tagId, now: now))
            }
        }
    }

    public func tags(of todoId: EntityID) throws -> [Tag] {
        try db.read { db in
            try Tag.fetchAll(db, sql: """
                SELECT tag.* FROM tag
                JOIN todoTag ON todoTag.tagId = tag.id AND todoTag.deletedAt IS NULL
                WHERE todoTag.todoId = ? AND tag.deletedAt IS NULL
                ORDER BY tag.position
                """, arguments: [todoId])
        }
    }

    // MARK: Checklist

    @discardableResult
    public func addChecklistItem(_ title: String, to todoId: EntityID, now: Date = Date()) throws -> ChecklistItem {
        try db.write { db in
            let max = try Double.fetchOne(db, sql: "SELECT MAX(position) FROM checklistItem WHERE todoId = ?", arguments: [todoId]) ?? 0
            let item = ChecklistItem(todoId: todoId, title: title, position: max + 1, now: now)
            try db.insertLogged(item)
            return item
        }
    }

    public func setChecklistItem(_ id: EntityID, done: Bool, now: Date = Date()) throws {
        try db.write { db in
            guard var item = try ChecklistItem.filter(key: id).fetchOne(db) else { throw PicoError.notFound(id) }
            item.isDone = done
            try db.updateLogged(&item, now: now)
        }
    }

    public func checklist(of todoId: EntityID) throws -> [ChecklistItem] {
        try db.read { db in
            try ChecklistItem.filter(Column("todoId") == todoId && Column("deletedAt") == nil)
                .order(Column("position")).fetchAll(db)
        }
    }

    // MARK: Internes

    static func nextPosition(_ db: Database, projectId: EntityID?, headingId: EntityID?) throws -> Double {
        let max: Double? = if let headingId {
            try Double.fetchOne(db, sql: "SELECT MAX(position) FROM todo WHERE headingId = ?", arguments: [headingId])
        } else if let projectId {
            try Double.fetchOne(db, sql: "SELECT MAX(position) FROM todo WHERE projectId = ? AND headingId IS NULL", arguments: [projectId])
        } else {
            try Double.fetchOne(db, sql: "SELECT MAX(position) FROM todo WHERE projectId IS NULL")
        }
        return (max ?? 0) + 1
    }

    static func copyTags(_ db: Database, from: EntityID, to: EntityID, now: Date) throws {
        let links = try TodoTag.filter(Column("todoId") == from && Column("deletedAt") == nil).fetchAll(db)
        for link in links {
            try db.insertLogged(TodoTag(todoId: to, tagId: link.tagId, now: now))
        }
    }

    static func copyChecklist(_ db: Database, from: EntityID, to: EntityID, now: Date) throws {
        let items = try ChecklistItem.filter(Column("todoId") == from && Column("deletedAt") == nil)
            .order(Column("position")).fetchAll(db)
        for item in items {
            try db.insertLogged(ChecklistItem(todoId: to, title: item.title, position: item.position, now: now))
        }
    }
}
