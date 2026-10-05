import Foundation
import GRDB

/// Zones, projets et en-tetes.
public struct ProjectService: Sendable {
    public let db: AppDatabase
    public init(db: AppDatabase) { self.db = db }

    // MARK: Zones

    @discardableResult
    public func createArea(_ name: String, icon: String? = nil, color: String? = nil, now: Date = Date()) throws -> Area {
        try db.write { db in
            let max = try Double.fetchOne(db, sql: "SELECT MAX(position) FROM area") ?? 0
            let area = Area(name: name, icon: icon, color: color, position: max + 1, now: now)
            try db.insertLogged(area)
            return area
        }
    }

    public func areas() throws -> [Area] {
        try db.read { db in
            try Area.filter(Column("deletedAt") == nil).order(Column("position")).fetchAll(db)
        }
    }

    public func save(_ area: Area, now: Date = Date()) throws {
        var area = area
        try db.write { db in try db.updateLogged(&area, now: now) }
    }

    public func deleteArea(_ id: EntityID, now: Date = Date()) throws {
        try db.write { db in
            guard var area = try Area.filter(key: id).fetchOne(db) else { throw PicoError.notFound(id) }
            try db.softDeleteLogged(&area, now: now)
            for var project in try Project.filter(Column("areaId") == id && Column("deletedAt") == nil).fetchAll(db) {
                project.areaId = nil
                try db.updateLogged(&project, now: now)
            }
        }
    }

    // MARK: Projets

    @discardableResult
    public func createProject(_ name: String, areaId: EntityID? = nil, notes: String = "",
                              plannedDate: DayDate? = nil, dueDate: DayDate? = nil, now: Date = Date()) throws -> Project {
        try db.write { db in
            let max = try Double.fetchOne(db, sql: "SELECT MAX(position) FROM project") ?? 0
            let project = Project(areaId: areaId, name: name, notes: notes, plannedDate: plannedDate,
                                  dueDate: dueDate, position: max + 1, now: now)
            try db.insertLogged(project)
            return project
        }
    }

    public func projects(status: ProjectStatus? = .active) throws -> [Project] {
        try db.read { db in
            var request = Project.filter(Column("deletedAt") == nil)
            if let status { request = request.filter(Column("status") == status.rawValue) }
            return try request.order(Column("position")).fetchAll(db)
        }
    }

    public func projects(inArea areaId: EntityID?) throws -> [Project] {
        try db.read { db in
            try Project.filter(Column("deletedAt") == nil && Column("areaId") == areaId
                               && Column("status") == ProjectStatus.active.rawValue)
                .order(Column("position")).fetchAll(db)
        }
    }

    public func project(_ id: EntityID) throws -> Project? {
        try db.read { db in try Project.filter(key: id).filter(Column("deletedAt") == nil).fetchOne(db) }
    }

    public func save(_ project: Project, now: Date = Date()) throws {
        var project = project
        try db.write { db in try db.updateLogged(&project, now: now) }
    }

    /// Termine le projet et toutes ses taches ouvertes.
    public func completeProject(_ id: EntityID, now: Date = Date()) throws {
        try db.write { db in
            guard var project = try Project.filter(key: id).fetchOne(db) else { throw PicoError.notFound(id) }
            project.status = .done
            try db.updateLogged(&project, now: now)
            for var todo in try Todo.open.filter(Column("projectId") == id).fetchAll(db) {
                todo.status = .done
                todo.completedAt = now
                try db.updateLogged(&todo, now: now)
            }
        }
    }

    public func deleteProject(_ id: EntityID, now: Date = Date()) throws {
        try db.write { db in
            guard var project = try Project.filter(key: id).fetchOne(db) else { throw PicoError.notFound(id) }
            try db.softDeleteLogged(&project, now: now)
            for var todo in try Todo.live.filter(Column("projectId") == id).fetchAll(db) {
                try db.softDeleteLogged(&todo, now: now)
            }
        }
    }

    /// Avancement : (terminees, total) parmi les taches non supprimees.
    public func progress(of projectId: EntityID) throws -> (done: Int, total: Int) {
        try db.read { db in
            let total = try Todo.live.filter(Column("projectId") == projectId).fetchCount(db)
            let done = try Todo.live.filter(Column("projectId") == projectId && Column("status") == TodoStatus.done.rawValue).fetchCount(db)
            return (done, total)
        }
    }

    // MARK: En-tetes

    @discardableResult
    public func createHeading(_ name: String, in projectId: EntityID, now: Date = Date()) throws -> Heading {
        try db.write { db in
            let max = try Double.fetchOne(db, sql: "SELECT MAX(position) FROM heading WHERE projectId = ?", arguments: [projectId]) ?? 0
            let heading = Heading(projectId: projectId, name: name, position: max + 1, now: now)
            try db.insertLogged(heading)
            return heading
        }
    }

    public func headings(of projectId: EntityID) throws -> [Heading] {
        try db.read { db in
            try Heading.filter(Column("projectId") == projectId && Column("deletedAt") == nil)
                .order(Column("position")).fetchAll(db)
        }
    }

    public func deleteHeading(_ id: EntityID, now: Date = Date()) throws {
        try db.write { db in
            guard var heading = try Heading.filter(key: id).fetchOne(db) else { throw PicoError.notFound(id) }
            try db.softDeleteLogged(&heading, now: now)
            for var todo in try Todo.live.filter(Column("headingId") == id).fetchAll(db) {
                todo.headingId = nil
                try db.updateLogged(&todo, now: now)
            }
        }
    }
}
