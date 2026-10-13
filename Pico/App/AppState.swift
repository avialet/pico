import Foundation
import Observation
import PicoCore
import AppKit

/// Destination de la barre laterale.
enum SidebarItem: Hashable, Codable {
    case inbox, today, upcoming, anytime, someday, logbook
    case project(EntityID)

    static let smartLists: [SidebarItem] = [.inbox, .today, .upcoming, .anytime, .someday, .logbook]

    var title: String {
        switch self {
        case .inbox: "Inbox"
        case .today: "Aujourd'hui"
        case .upcoming: "À venir"
        case .anytime: "À tout moment"
        case .someday: "Un jour"
        case .logbook: "Journal"
        case .project: "Projet"
        }
    }

    var systemImage: String {
        switch self {
        case .inbox: "tray.fill"
        case .today: "sun.max.fill"
        case .upcoming: "calendar"
        case .anytime: "square.stack.3d.up.fill"
        case .someday: "moon.stars.fill"
        case .logbook: "book.closed.fill"
        case .project: "circle"
        }
    }
}

/// Section d'une liste (en-tete de projet, jour a venir, "Hier"...).
struct TodoSection: Identifiable, Hashable {
    let id: String
    let title: String?
    let subtitle: String?
    let todos: [Todo]
}

/// Etat global : base, services, selection, caches d'affichage.
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
    var selectionAnchor: EntityID?
    var editingTodoId: EntityID?
    var searchText = ""
    var showInspector = true
    /// Mode capture (DEBUG) : liste posee sans ScrollView, que le rendu par calques ne dessine pas.
    var snapshotLayout = false
    var quickAddFocused = false
    /// Incremente pour demander le focus (saisie rapide, recherche).
    var quickAddFocusRequest = 0
    var searchFocusRequest = 0
    /// Derniere tache creee, pour une breve mise en valeur.
    var flashTodoId: EntityID?

    private(set) var areas: [Area] = []
    private(set) var activeProjects: [Project] = []
    private(set) var sections: [TodoSection] = []
    private(set) var inboxCount = 0
    private(set) var todayCount = 0
    private(set) var allTags: [Tag] = []
    private(set) var projectProgress: [EntityID: Tally] = [:]
    private(set) var checklistTally: [EntityID: Tally] = [:]
    private(set) var tagsByTodo: [EntityID: [Tag]] = [:]

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
            projectProgress = try projects.progressIndex()
            checklistTally = try todos.checklistIndex()
            tagsByTodo = try todos.tagIndex()
            sections = try buildSections()
            let visible = Set(visibleTodos.map(\.id))
            if !selectedTodoIds.isSubset(of: visible) { selectedTodoIds = selectedTodoIds.intersection(visible) }
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
            if !late.isEmpty {
                result.append(TodoSection(id: "late", title: "Pas encore fait", subtitle: "prévu avant aujourd'hui", todos: late))
            }
            result.append(TodoSection(id: "day", title: late.isEmpty && evening.isEmpty ? nil : "Aujourd'hui", subtitle: nil, todos: day))
            if !evening.isEmpty {
                result.append(TodoSection(id: "evening", title: "Ce soir", subtitle: nil, todos: evening))
            }
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
            var result = [TodoSection(id: "none", title: nil, subtitle: nil, todos: all.filter { $0.headingId == nil })]
            for h in try projects.headings(of: id) {
                result.append(TodoSection(id: h.id.rawValue, title: h.name, subtitle: nil, todos: all.filter { $0.headingId == h.id }))
            }
            return result
        }
    }

    // MARK: Lecture

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

    var parser: QuickEntryParser {
        QuickEntryParser(today: today, projects: activeProjects.map { ($0.id, $0.name) })
    }

    /// Somme des durees estimees prevues aujourd'hui (hors retard).
    var todayLoadMinutes: Int {
        sections.filter { $0.id != "late" }.flatMap(\.todos).compactMap(\.durationMinutes).reduce(0, +)
    }

    // MARK: Selection

    func select(_ id: EntityID, extend: Bool = false, range: Bool = false) {
        let list = visibleTodos
        if range, let anchor = selectionAnchor,
           let a = list.firstIndex(where: { $0.id == anchor }), let b = list.firstIndex(where: { $0.id == id }) {
            selectedTodoIds = Set(list[min(a, b)...max(a, b)].map(\.id))
            return
        }
        if extend {
            if selectedTodoIds.contains(id) { selectedTodoIds.remove(id) } else { selectedTodoIds.insert(id) }
        } else {
            selectedTodoIds = [id]
        }
        selectionAnchor = id
    }

    func moveSelection(_ delta: Int) {
        let list = visibleTodos
        guard !list.isEmpty else { return }
        let current = delta > 0 ? list.lastIndex { selectedTodoIds.contains($0.id) } : list.firstIndex { selectedTodoIds.contains($0.id) }
        let next = current.map { max(0, min(list.count - 1, $0 + delta)) } ?? (delta > 0 ? 0 : list.count - 1)
        selectedTodoIds = [list[next].id]
        selectionAnchor = list[next].id
    }

    // MARK: Saisie rapide

    func focusQuickAdd() { quickAddFocusRequest += 1 }
    func focusSearch() { searchFocusRequest += 1 }

    /// Cree la tache decrite par une ligne analysee, dans le contexte de la liste courante.
    func quickAdd(_ parsed: ParsedEntry) {
        guard !parsed.title.isEmpty else { NSSound.beep(); return }
        run {
            var entry = parsed
            if entry.projectId == nil, let name = entry.projectName, !name.isEmpty {
                entry.projectId = try projects.createProject(name).id
            }
            var todo = entry.makeTodo()
            if case .project(let id) = selection, todo.projectId == nil { todo.projectId = id }
            if todo.plannedDate == nil, !todo.isSomeday {
                switch selection {
                case .today: todo.plannedDate = today
                case .upcoming: todo.plannedDate = today.adding(days: 1)
                case .someday: todo.isSomeday = true
                default: break
                }
            }
            todo.isInbox = todo.projectId == nil && todo.plannedDate == nil && !todo.isSomeday && selection != .anytime
            if selection == .logbook || !searchText.isEmpty {
                searchText = ""
            }
            let created = try todos.create(todo)
            if !entry.tagNames.isEmpty {
                let tagIds = try entry.tagNames.map { try tags.findOrCreate($0).id }
                try todos.setTags(tagIds, on: created.id)
            }
            flashTodoId = created.id
        }
        if let id = flashTodoId, !visibleTodos.contains(where: { $0.id == id }), let created = try? todos.fetch(id) {
            // La tache n'est pas dans la liste courante : on suit sa destination.
            if created.isInbox { selection = .inbox }
            else if let p = created.projectId, selection != .project(p) { selection = .project(p) }
            else if created.isSomeday { selection = .someday }
            else if let d = created.plannedDate { selection = d <= today ? .today : .upcoming }
            else { selection = .anytime }
            reload()
        }
    }

    // MARK: Capture (fenetre flottante)

    /// Cree la tache telle que decrite, sans contexte de liste ni navigation.
    @discardableResult
    func capture(_ parsed: ParsedEntry) -> Todo? {
        guard !parsed.title.isEmpty else { return nil }
        var created: Todo?
        run {
            var entry = parsed
            if entry.projectId == nil, let name = entry.projectName, !name.isEmpty {
                entry.projectId = try projects.createProject(name).id
            }
            let todo = try todos.create(entry.makeTodo())
            if !entry.tagNames.isEmpty {
                try todos.setTags(try entry.tagNames.map { try tags.findOrCreate($0).id }, on: todo.id)
            }
            created = todo
        }
        return created
    }

    /// Ou la tache a atterri : "Inbox", "Aujourd'hui", "Ven. 9 oct.", "Migration serveurs"...
    func destinationLabel(of todo: Todo) -> String {
        if todo.isSomeday { return "Un jour" }
        if let d = todo.plannedDate { return d <= today ? "Aujourd'hui" : d.relativeLabel(today: today) }
        if let p = project(todo.projectId) { return p.name }
        return todo.isInbox ? "Inbox" : "À tout moment"
    }

    // MARK: Actions sur les taches

    func save(_ todo: Todo) { run { try todos.save(todo) } }

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

    func delete(ids: Set<EntityID>? = nil) {
        for id in ids ?? selectedTodoIds { run { try todos.delete(id) } }
        selectedTodoIds.subtract(ids ?? selectedTodoIds)
    }

    /// Glisser-deposer : place `id` juste avant `targetId` et adopte le contexte
    /// de la cible (jour, moment, en-tete) si elle vient d'une autre section.
    func drop(_ id: EntityID, before targetId: EntityID, in section: TodoSection) {
        guard id != targetId else { return }
        var ids = section.todos.map(\.id)
        if !ids.contains(id), let target = todo(targetId), var moving = todo(id) {
            if selection == .today || selection == .upcoming {
                moving.plannedDate = target.plannedDate
                moving.plannedSlot = target.plannedSlot
            }
            if moving.projectId == target.projectId { moving.headingId = target.headingId }
            run { try todos.save(moving) }
        }
        ids.removeAll { $0 == id }
        ids.insert(id, at: ids.firstIndex(of: targetId) ?? ids.count)
        run { try todos.reorder(ids) }
    }

    // MARK: Projets et zones

    func newProject(in areaId: EntityID? = nil) {
        run {
            let p = try projects.createProject("Nouveau projet", areaId: areaId)
            selection = .project(p.id)
        }
    }

    func newArea() { run { try projects.createArea("Nouvelle zone") } }

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
        if selection == .project(id) { selection = .logbook }
    }

    func deleteProject(_ id: EntityID) {
        run { try projects.deleteProject(id) }
        if selection == .project(id) { selection = .inbox }
    }

    func deleteArea(_ id: EntityID) { run { try projects.deleteArea(id) } }

    func newHeading(in projectId: EntityID) {
        run { try projects.createHeading("Nouvelle section", in: projectId) }
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
