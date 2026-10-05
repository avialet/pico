import Foundation
import GRDB

public struct TagService: Sendable {
    public let db: AppDatabase
    public init(db: AppDatabase) { self.db = db }

    public func tags() throws -> [Tag] {
        try db.read { db in
            try Tag.filter(Column("deletedAt") == nil).order(Column("position")).fetchAll(db)
        }
    }

    /// Trouve un tag par nom (insensible a la casse) ou le cree.
    @discardableResult
    public func findOrCreate(_ name: String, now: Date = Date()) throws -> Tag {
        let name = name.trimmingCharacters(in: .whitespaces)
        return try db.write { db in
            if let tag = try Tag.filter(Column("deletedAt") == nil)
                .filter(sql: "lower(name) = lower(?)", arguments: [name]).fetchOne(db) {
                return tag
            }
            let max = try Double.fetchOne(db, sql: "SELECT MAX(position) FROM tag") ?? 0
            let tag = Tag(name: name, position: max + 1, now: now)
            try db.insertLogged(tag)
            return tag
        }
    }

    public func delete(_ id: EntityID, now: Date = Date()) throws {
        try db.write { db in
            guard var tag = try Tag.filter(key: id).fetchOne(db) else { throw PicoError.notFound(id) }
            try db.softDeleteLogged(&tag, now: now)
            for var link in try TodoTag.filter(Column("tagId") == id && Column("deletedAt") == nil).fetchAll(db) {
                try db.softDeleteLogged(&link, now: now)
            }
        }
    }
}
