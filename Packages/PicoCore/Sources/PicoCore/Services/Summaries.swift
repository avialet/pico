import Foundation
import GRDB

/// Compteur "fait / total" (checklist, projet).
public struct Tally: Sendable, Hashable {
    public let done: Int
    public let total: Int
    public init(done: Int, total: Int) { self.done = done; self.total = total }
    public var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
}

public extension TodoService {
    /// Avancement des checklists, par tache.
    func checklistIndex() throws -> [EntityID: Tally] {
        try db.read { db in
            var result: [EntityID: Tally] = [:]
            for row in try Row.fetchAll(db, sql: """
                SELECT todoId, SUM(isDone) AS done, COUNT(*) AS total
                FROM checklistItem WHERE deletedAt IS NULL GROUP BY todoId
                """) {
                result[row["todoId"]] = Tally(done: row["done"], total: row["total"])
            }
            return result
        }
    }

    /// Tags actifs, par tache.
    func tagIndex() throws -> [EntityID: [Tag]] {
        try db.read { db in
            var result: [EntityID: [Tag]] = [:]
            for row in try Row.fetchAll(db, sql: """
                SELECT todoTag.todoId AS linkTodoId, tag.* FROM todoTag
                JOIN tag ON tag.id = todoTag.tagId AND tag.deletedAt IS NULL
                WHERE todoTag.deletedAt IS NULL ORDER BY tag.position
                """) {
                let todoId: EntityID = row["linkTodoId"]
                result[todoId, default: []].append(try Tag(row: row))
            }
            return result
        }
    }
}

public extension ProjectService {
    /// Avancement de chaque projet (taches terminees / non supprimees).
    func progressIndex() throws -> [EntityID: Tally] {
        try db.read { db in
            var result: [EntityID: Tally] = [:]
            for row in try Row.fetchAll(db, sql: """
                SELECT projectId, SUM(status = 'done') AS done, COUNT(*) AS total
                FROM todo WHERE deletedAt IS NULL AND projectId IS NOT NULL AND status != 'cancelled'
                GROUP BY projectId
                """) {
                result[row["projectId"]] = Tally(done: row["done"], total: row["total"])
            }
            return result
        }
    }
}
