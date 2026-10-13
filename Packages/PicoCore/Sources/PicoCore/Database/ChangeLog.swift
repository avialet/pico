import Foundation
import GRDB

/// Journal append-only de toutes les ecritures, base de la future sync.
public struct ChangeLogEntry: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "changeLog"
    public enum Op: String, Codable, Sendable, DatabaseValueConvertible { case insert, update, delete }

    public var seq: Int64?
    public var entity: String
    public var entityId: EntityID
    public var op: Op
    public var payload: String
    public var at: Date
    public var deviceId: String

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        seq = inserted.rowID
    }
}

enum Meta {
    static func value(_ key: String, in db: Database) throws -> String? {
        try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = ?", arguments: [key])
    }
    static func set(_ key: String, _ value: String, in db: Database) throws {
        try db.execute(sql: "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", arguments: [key, value])
    }
}

let payloadEncoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    e.outputFormatting = [.sortedKeys]
    return e
}()

public extension Database {
    /// Insere et journalise.
    func insertLogged<R: SyncedRecord>(_ record: R) throws {
        try record.insert(self)
        try log(.insert, record)
    }

    /// Met a jour `updatedAt`, sauvegarde et journalise.
    func updateLogged<R: SyncedRecord>(_ record: inout R, now: Date = Date()) throws {
        record.updatedAt = now
        try record.update(self)
        try log(.update, record)
    }

    /// Suppression douce : la ligne reste, `deletedAt` est pose.
    func softDeleteLogged<R: SyncedRecord>(_ record: inout R, now: Date = Date()) throws {
        record.deletedAt = now
        record.updatedAt = now
        try record.update(self)
        try log(.delete, record)
    }

    private func log<R: SyncedRecord>(_ op: ChangeLogEntry.Op, _ record: R) throws {
        let payload = String(decoding: try payloadEncoder.encode(record), as: UTF8.self)
        let deviceId = try Meta.value("deviceId", in: self) ?? "unknown"
        let entry = ChangeLogEntry(seq: nil, entity: R.entityName, entityId: record.id, op: op,
                                   payload: payload, at: Date(), deviceId: deviceId)
        try entry.insert(self)
    }
}
