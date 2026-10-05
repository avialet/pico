import Foundation
import GRDB

/// Tout enregistrement synchronisable : identifiant texte, horodatages,
/// suppression douce. Les ecritures passent par `Database.insertLogged`,
/// `updateLogged`, `softDeleteLogged` qui alimentent le journal.
public protocol SyncedRecord: Codable, Sendable, Identifiable, FetchableRecord, PersistableRecord
where ID == EntityID {
    static var entityName: String { get }
    var id: EntityID { get }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
}

public extension SyncedRecord {
    static var databaseTableName: String { entityName }
}

public enum ProjectStatus: String, Codable, Sendable, DatabaseValueConvertible {
    case active, someday, done
}

public enum TodoStatus: String, Codable, Sendable, DatabaseValueConvertible {
    case open, done, cancelled
}

public enum PlannedSlot: String, Codable, Sendable, DatabaseValueConvertible {
    case day, evening
}

public struct Area: SyncedRecord, Hashable {
    public static let entityName = "area"
    public var id: EntityID
    public var name: String
    public var icon: String?
    public var color: String?
    public var position: Double
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(id: EntityID = .new(), name: String, icon: String? = nil, color: String? = nil,
                position: Double = 0, now: Date = Date()) {
        self.id = id; self.name = name; self.icon = icon; self.color = color
        self.position = position; createdAt = now; updatedAt = now; deletedAt = nil
    }
}

public struct Project: SyncedRecord, Hashable {
    public static let entityName = "project"
    public var id: EntityID
    public var areaId: EntityID?
    public var name: String
    public var notes: String
    public var status: ProjectStatus
    public var plannedDate: DayDate?
    public var dueDate: DayDate?
    public var position: Double
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(id: EntityID = .new(), areaId: EntityID? = nil, name: String, notes: String = "",
                status: ProjectStatus = .active, plannedDate: DayDate? = nil, dueDate: DayDate? = nil,
                position: Double = 0, now: Date = Date()) {
        self.id = id; self.areaId = areaId; self.name = name; self.notes = notes; self.status = status
        self.plannedDate = plannedDate; self.dueDate = dueDate; self.position = position
        createdAt = now; updatedAt = now; deletedAt = nil
    }
}

public struct Heading: SyncedRecord, Hashable {
    public static let entityName = "heading"
    public var id: EntityID
    public var projectId: EntityID
    public var name: String
    public var position: Double
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(id: EntityID = .new(), projectId: EntityID, name: String, position: Double = 0, now: Date = Date()) {
        self.id = id; self.projectId = projectId; self.name = name; self.position = position
        createdAt = now; updatedAt = now; deletedAt = nil
    }
}

/// Une tache. Nommee `Todo` pour ne pas masquer `Swift.Task`.
public struct Todo: SyncedRecord, Hashable {
    public static let entityName = "todo"
    public var id: EntityID
    public var projectId: EntityID?
    public var headingId: EntityID?
    public var title: String
    public var notes: String
    public var status: TodoStatus
    /// 0 = normale, 1 = basse, 2 = haute, 3 = urgente.
    public var priority: Int
    /// Jour ou l'on compte s'en occuper (Aujourd'hui / A venir).
    public var plannedDate: DayDate?
    public var plannedSlot: PlannedSlot
    /// Minutes depuis minuit, pour un rappel a heure fixe.
    public var plannedTime: Int?
    /// Date limite reelle, distincte du jour prevu.
    public var dueDate: DayDate?
    public var durationMinutes: Int?
    /// Regle serialisee, voir `RecurrenceRule`.
    public var recurrenceRule: String?
    public var recurrenceParentId: EntityID?
    public var completedAt: Date?
    /// Origine externe (jira, trello, outlook, asana...).
    public var source: String?
    public var externalKey: String?
    public var externalURL: String?
    public var isInbox: Bool
    public var isSomeday: Bool
    public var position: Double
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(id: EntityID = .new(), projectId: EntityID? = nil, headingId: EntityID? = nil,
                title: String, notes: String = "", status: TodoStatus = .open, priority: Int = 0,
                plannedDate: DayDate? = nil, plannedSlot: PlannedSlot = .day, plannedTime: Int? = nil,
                dueDate: DayDate? = nil, durationMinutes: Int? = nil, recurrenceRule: String? = nil,
                recurrenceParentId: EntityID? = nil, completedAt: Date? = nil, source: String? = nil,
                externalKey: String? = nil, externalURL: String? = nil, isInbox: Bool? = nil,
                isSomeday: Bool = false, position: Double = 0, now: Date = Date()) {
        self.id = id; self.projectId = projectId; self.headingId = headingId; self.title = title
        self.notes = notes; self.status = status; self.priority = priority
        self.plannedDate = plannedDate; self.plannedSlot = plannedSlot; self.plannedTime = plannedTime
        self.dueDate = dueDate; self.durationMinutes = durationMinutes
        self.recurrenceRule = recurrenceRule; self.recurrenceParentId = recurrenceParentId
        self.completedAt = completedAt; self.source = source; self.externalKey = externalKey
        self.externalURL = externalURL
        self.isInbox = isInbox ?? (projectId == nil && plannedDate == nil && !isSomeday)
        self.isSomeday = isSomeday; self.position = position
        createdAt = now; updatedAt = now; deletedAt = nil
    }

    public var recurrence: RecurrenceRule? {
        get { recurrenceRule.flatMap(RecurrenceRule.init(string:)) }
        set { recurrenceRule = newValue?.string }
    }
}

public struct ChecklistItem: SyncedRecord, Hashable {
    public static let entityName = "checklistItem"
    public var id: EntityID
    public var todoId: EntityID
    public var title: String
    public var isDone: Bool
    public var position: Double
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(id: EntityID = .new(), todoId: EntityID, title: String, isDone: Bool = false,
                position: Double = 0, now: Date = Date()) {
        self.id = id; self.todoId = todoId; self.title = title; self.isDone = isDone
        self.position = position; createdAt = now; updatedAt = now; deletedAt = nil
    }
}

public struct Tag: SyncedRecord, Hashable {
    public static let entityName = "tag"
    public var id: EntityID
    public var name: String
    public var color: String?
    public var position: Double
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(id: EntityID = .new(), name: String, color: String? = nil, position: Double = 0, now: Date = Date()) {
        self.id = id; self.name = name; self.color = color; self.position = position
        createdAt = now; updatedAt = now; deletedAt = nil
    }
}

public struct TodoTag: SyncedRecord, Hashable {
    public static let entityName = "todoTag"
    public var id: EntityID
    public var todoId: EntityID
    public var tagId: EntityID
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(id: EntityID = .new(), todoId: EntityID, tagId: EntityID, now: Date = Date()) {
        self.id = id; self.todoId = todoId; self.tagId = tagId
        createdAt = now; updatedAt = now; deletedAt = nil
    }
}

/// Vue sauvegardee : un filtre serialise en JSON (voir `TodoFilter`).
public struct Perspective: SyncedRecord, Hashable {
    public static let entityName = "perspective"
    public var id: EntityID
    public var name: String
    public var icon: String?
    public var filterJSON: String
    public var position: Double
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(id: EntityID = .new(), name: String, icon: String? = nil, filterJSON: String,
                position: Double = 0, now: Date = Date()) {
        self.id = id; self.name = name; self.icon = icon; self.filterJSON = filterJSON
        self.position = position; createdAt = now; updatedAt = now; deletedAt = nil
    }
}
