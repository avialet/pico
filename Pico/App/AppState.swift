import Foundation
import Observation
import PicoCore
import AppKit

/// Destination de la barre laterale.
enum SidebarItem: Hashable, Codable {
    case inbox, today, upcoming, anytime, someday, logbook
    case project(EntityID)

    var title: String {
        switch self {
        case .inbox: "Inbox"
        case .today: "Aujourd'hui"
        case .upcoming: "A venir"
        case .anytime: "A tout moment"
        case .someday: "Un jour"
        case .logbook: "Journal"
        case .project: "Projet"
        }
    }

    var systemImage: String {
        switch self {
        case .inbox: "tray"
        case .today: "star"
        case .upcoming: "calendar"
        case .anytime: "square.stack"
        case .someday: "archivebox"
        case .logbook: "book.closed"
        case .project: "circle"
        }
    }
}

/// Section d'une liste de taches (en-tete de projet, jour a venir, "Hier"...).
struct TodoSection: Identifiable, Hashable {
    let id: String
    let title: String?
    let subtitle: String?
    let todos: [Todo]
}

/// Etat global de l'app : base, services, selection, caches.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    let db: AppDatabase
    let todos: TodoService
    let projects: ProjectService
    let tags: TagService

    var selection: SidebarItem = .today
    var selectedTodoIds: Set<EntityID> = []
    var editingTodoId: EntityID?
    var searchText = ""
    var showInspector = true

    private(set) var areas: [Area] = []
    private(set) var activeProjects: [Project] = []
    private(set) var sections: [TodoSection] = []
    private(set) var inboxCount = 0
    private(set) var todayCount = 0
    private(set) var allTags: [Tag] = []

    var today: DayDate { .today() }

    private init() {
        let database: AppDatabase
        do {
            database = try AppDatabase.open()
        } catch {
            fatalError("Impossible d'ouvrir la base Pico : \(error)")
        }
        db = database
        todos = TodoService(db: database)
        projects = ProjectService(db: database)
        tags = TagService(db: database)
        reload()
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(AppDatabase.didChangeNotification), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    // MARK: Chargement

    func reload() {
        do {
            areas = try projects.areas()
            activeProjects = try projects.projects(status: .active)
            allTags = try tags.tags()
            inboxCount = try todos.inbox().count
            todayCount = try todos.today(today).count
            sections = try buildSections()
            let visible = Set(sections.flatMap(\.todos).map(\.id))
            selectedTodoIds = selectedTodoIds.intersection(visible)
        } catch {
            NSLog("Pico reload: \(error)")
        }
    }

    private func buildSections() throws -> [TodoSection] {
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return [TodoSection(id: "search", title: nil, subtitle: nil, todos: try todos.search(searchText))]
        }
        switch selection {
        case .inbox:
            return [TodoSection(id: "inbox", title: nil, subtitle: nil, todos: try todos.inbox())]
        case .today:
            let all = try todos.today(today)
            let late = all.filter { ($0.plannedDate ?? today) < today }
            let day = all.filter { ($0.plannedDate ?? today) >= today && $0.plannedSlot == .day }
            let evening = all.filter { ($0.plannedDate ?? today) >= today && $0.plannedSlot == .evening }
            var result: [TodoSection] = []
            if !late.isEmpty { result.append(TodoSection(id: "late", title: "Hier, non fait", subtitle: "A replanifier", todos: late)) }
            result.append(TodoSection(id: "day", title: result.isEmpty && evening.isEmpty ? nil : "Aujourd'hui", subtitle: nil, todos: day))
            if !evening.isEmpty { result.append(TodoSection(id: "evening", title: "Ce soir", subtitle: nil, todos: evening)) }
            return result
        case .upcoming:
            let all = try todos.upcoming(from: today, days: 365)
            let grouped = Dictionary(grouping: all) { $0.plannedDate! }
            return grouped.keys.sorted().map { day in
                TodoSection(id: day.isoString, title: day.relativeLabel(today: today), subtitle: day.weekdayLabel, todos: grouped[day]!)
            }
        case .anytime:
            return [TodoSection(id: "anytime", title: nil, subtitle: nil, todos: try todos.anytime())]
        case .someday:
            return [TodoSection(id: "someday", title: nil, subtitle: nil, todos: try todos.someday())]
        case .logbook:
            return [TodoSection(id: "logbook", title: nil, subtitle: nil, todos: try todos.logbook())]
        case .project(let id):
            let all = try todos.todos(inProject: id)
            let headings = try projects.headings(of: id)
            var result = [TodoSection(id: "none", title: nil, subtitle: nil, todos: all.filter { $0.headingId == nil })]
            for h in headings {
                result.append(TodoSection(id: h.id.rawValue, title: h.name, subtitle: nil, todos: all.filter { $0.headingId == h.id }))
            }
            return result
        }
    }

    var currentProject: Project? {
        if case .project(let id) = selection { return activeProjects.first { $0.id == id } }
        return nil
    }

    var visibleTodos: [Todo] { sections.flatMap(\.todos) }

    func todo(_ id: EntityID) -> Todo? { visibleTodos.first { $0.id == id } ?? (try? todos.fetch(id)) }

    func project(_ id: EntityID?) -> Project? {
        guard let id else { return nil }
        return activeProjects.first { $0.id == id }
    }

    // MARK: Actions sur les taches

    /// Nouvelle tache dans le contexte de la liste courante, en edition.
    func newTodo() {
        var todo = Todo(title: "Nouvelle tache")
        switch selection {
        case .today: todo.plannedDate = today
        case .upcoming: todo.plannedDate = today.adding(days: 1)
        case .anytime: todo.isInbox = false
        case .someday: todo.isSomeday = true; todo.isInbox = false
        case .project(let id): todo.projectId = id
        case .inbox, .logbook: break
        }
        if selection == .logbook { selection = .inbox }
        todo.isInbox = todo.projectId == nil && todo.plannedDate == nil && !todo.isSomeday
        run {
            let created = try todos.create(todo)
            selectedTodoIds = [created.id]
            editingTodoId = created.id
        }
    }

    func save(_ todo: Todo) {
        run { try todos.save(todo) }
    }

    func toggleComplete(_ ids: Set<EntityID>? = nil) {
        for id in ids ?? selectedTodoIds {
            guard let todo = todo(id) else { continue }
            run {
                if todo.status == .open { try todos.complete(id, today: today) } else { try todos.reopen(id) }
            }
        }
    }

    func plan(_ date: DayDate?, slot: PlannedSlot = .day, ids: Set<EntityID>? = nil) {
        for id in ids ?? selectedTodoIds { run { try todos.plan(id, on: date, slot: slot) } }
    }

    func moveToSomeday(ids: Set<EntityID>? = nil) {
        for id in ids ?? selectedTodoIds { run { try todos.moveToSomeday(id) } }
    }

    func move(ids: Set<EntityID>? = nil, toProject projectId: EntityID?) {
        for id in ids ?? selectedTodoIds { run { try todos.move(id, toProject: projectId) } }
    }

    func deleteSelected() {
        for id in selectedTodoIds { run { try todos.delete(id) } }
        selectedTodoIds = []
    }

    func reorder(_ ids: [EntityID]) {
        run { try todos.reorder(ids) }
    }

    // MARK: Projets et zones

    func newProject() {
        run {
            let areaId: EntityID? = if case .project(let id) = selection { project(id)?.areaId } else { nil }
            let p = try projects.createProject("Nouveau projet", areaId: areaId)
            selection = .project(p.id)
        }
    }

    func newArea() {
        run { try projects.createArea("Nouvelle zone") }
    }

    func rename(project: Project, to name: String) {
        var p = project; p.name = name
        run { try projects.save(p) }
    }

    func rename(area: Area, to name: String) {
        var a = area; a.name = name
        run { try projects.save(a) }
    }

    func saveProject(_ project: Project) { run { try projects.save(project) } }

    func completeProject(_ id: EntityID) {
        run { try projects.completeProject(id) }
        if selection == .project(id) { selection = .anytime }
    }

    func deleteProject(_ id: EntityID) {
        run { try projects.deleteProject(id) }
        if selection == .project(id) { selection = .inbox }
    }

    func deleteArea(_ id: EntityID) { run { try projects.deleteArea(id) } }

    func newHeading(in projectId: EntityID) {
        run { try projects.createHeading("Nouvel en-tete", in: projectId) }
    }

    // MARK: Interne

    func run(_ block: () throws -> Void) {
        do {
            try block()
        } catch {
            NSLog("Pico: \(error)")
            NSSound.beep()
        }
        reload()
    }
}
