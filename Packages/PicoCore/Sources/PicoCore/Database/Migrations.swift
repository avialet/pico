import Foundation
import GRDB

enum Migrations {
    static var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        #if DEBUG
        m.eraseDatabaseOnSchemaChange = true
        #endif

        m.registerMigration("v1") { db in
            func synced(_ t: TableDefinition) {
                t.primaryKey("id", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("deletedAt", .datetime)
            }

            try db.create(table: "meta") { t in
                t.primaryKey("key", .text)
                t.column("value", .text).notNull()
            }

            try db.create(table: "area") { t in
                synced(t)
                t.column("name", .text).notNull()
                t.column("icon", .text)
                t.column("color", .text)
                t.column("position", .double).notNull().defaults(to: 0)
            }

            try db.create(table: "project") { t in
                synced(t)
                t.column("areaId", .text).references("area", onDelete: .setNull)
                t.column("name", .text).notNull()
                t.column("notes", .text).notNull().defaults(to: "")
                t.column("status", .text).notNull().defaults(to: "active")
                t.column("plannedDate", .text)
                t.column("dueDate", .text)
                t.column("position", .double).notNull().defaults(to: 0)
            }

            try db.create(table: "heading") { t in
                synced(t)
                t.column("projectId", .text).notNull().references("project", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("position", .double).notNull().defaults(to: 0)
            }

            try db.create(table: "todo") { t in
                synced(t)
                t.column("projectId", .text).references("project", onDelete: .setNull)
                t.column("headingId", .text).references("heading", onDelete: .setNull)
                t.column("title", .text).notNull()
                t.column("notes", .text).notNull().defaults(to: "")
                t.column("status", .text).notNull().defaults(to: "open")
                t.column("priority", .integer).notNull().defaults(to: 0)
                t.column("plannedDate", .text)
                t.column("plannedSlot", .text).notNull().defaults(to: "day")
                t.column("plannedTime", .integer)
                t.column("dueDate", .text)
                t.column("durationMinutes", .integer)
                t.column("recurrenceRule", .text)
                t.column("recurrenceParentId", .text)
                t.column("completedAt", .datetime)
                t.column("source", .text)
                t.column("externalKey", .text)
                t.column("externalURL", .text)
                t.column("isInbox", .boolean).notNull().defaults(to: false)
                t.column("isSomeday", .boolean).notNull().defaults(to: false)
                t.column("position", .double).notNull().defaults(to: 0)
            }
            try db.create(index: "todo_status_planned", on: "todo", columns: ["status", "plannedDate"])
            try db.create(index: "todo_project", on: "todo", columns: ["projectId", "position"])
            try db.create(index: "todo_external", on: "todo", columns: ["source", "externalKey"])

            try db.create(table: "checklistItem") { t in
                synced(t)
                t.column("todoId", .text).notNull().references("todo", onDelete: .cascade)
                t.column("title", .text).notNull()
                t.column("isDone", .boolean).notNull().defaults(to: false)
                t.column("position", .double).notNull().defaults(to: 0)
            }

            try db.create(table: "tag") { t in
                synced(t)
                t.column("name", .text).notNull()
                t.column("color", .text)
                t.column("position", .double).notNull().defaults(to: 0)
            }

            try db.create(table: "todoTag") { t in
                synced(t)
                t.column("todoId", .text).notNull().references("todo", onDelete: .cascade)
                t.column("tagId", .text).notNull().references("tag", onDelete: .cascade)
                t.uniqueKey(["todoId", "tagId"])
            }

            try db.create(table: "perspective") { t in
                synced(t)
                t.column("name", .text).notNull()
                t.column("icon", .text)
                t.column("filterJSON", .text).notNull()
                t.column("position", .double).notNull().defaults(to: 0)
            }

            try db.create(table: "changeLog") { t in
                t.autoIncrementedPrimaryKey("seq")
                t.column("entity", .text).notNull()
                t.column("entityId", .text).notNull()
                t.column("op", .text).notNull()
                t.column("payload", .text).notNull()
                t.column("at", .datetime).notNull()
                t.column("deviceId", .text).notNull()
            }
            try db.create(index: "changeLog_entity", on: "changeLog", columns: ["entity", "entityId"])
        }
        return m
    }
}
