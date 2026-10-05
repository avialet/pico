import SwiftUI
import PicoCore

struct TodoListView: View {
    @Environment(AppState.self) private var state
    @FocusState private var focusedTodo: EntityID?

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            if let project = state.currentProject {
                ProjectHeaderView(project: project)
            }
            List(selection: $state.selectedTodoIds) {
                ForEach(state.sections) { section in
                    if let title = section.title {
                        Section {
                            sectionRows(section)
                        } header: {
                            sectionHeader(section, title: title)
                        }
                    } else {
                        sectionRows(section)
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .overlay {
                if state.visibleTodos.isEmpty { emptyState }
            }
            .contextMenu(forSelectionType: EntityID.self) { ids in
                todoContextMenu(ids)
            } primaryAction: { ids in
                if let id = ids.first { state.editingTodoId = id; focusedTodo = id }
            }
        }
        .onChange(of: state.editingTodoId) { _, id in focusedTodo = id }
        .onKeyPress(.return) {
            guard focusedTodo == nil, let id = state.selectedTodoIds.first else { return .ignored }
            state.editingTodoId = id
            return .handled
        }
        .onKeyPress(.space) {
            guard focusedTodo == nil, !state.selectedTodoIds.isEmpty else { return .ignored }
            state.toggleComplete()
            return .handled
        }
        .navigationTitle(state.currentProject?.name ?? state.selection.title)
    }

    @ViewBuilder
    private func sectionRows(_ section: TodoSection) -> some View {
        ForEach(section.todos) { todo in
            TodoRow(todo: todo, focused: $focusedTodo)
                .tag(todo.id)
                .draggable("todo:" + todo.id.rawValue)
        }
        .onMove { from, to in
            var ids = section.todos.map(\.id)
            ids.move(fromOffsets: from, toOffset: to)
            state.reorder(ids)
        }
        if section.todos.isEmpty && section.title != nil {
            Text("Rien ici").foregroundStyle(.tertiary).font(.callout)
        }
    }

    private func sectionHeader(_ section: TodoSection, title: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            if let subtitle = section.subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            if section.id == "late" {
                Spacer()
                Button("Tout replanifier a aujourd'hui") {
                    state.plan(state.today, ids: Set(section.todos.map(\.id)))
                }
                .buttonStyle(.link).font(.caption)
            }
        }
    }

    @ViewBuilder
    private func todoContextMenu(_ ids: Set<EntityID>) -> some View {
        Button("Terminer / rouvrir") { state.toggleComplete(ids) }
        Menu("Prevoir") {
            Button("Aujourd'hui") { state.plan(state.today, ids: ids) }
            Button("Ce soir") { state.plan(state.today, slot: .evening, ids: ids) }
            Button("Demain") { state.plan(state.today.adding(days: 1), ids: ids) }
            Button("Lundi prochain") { state.plan(state.today.startOfWeek.adding(days: 7), ids: ids) }
            Button("A tout moment") { state.plan(nil, ids: ids) }
            Button("Un jour") { state.moveToSomeday(ids: ids) }
        }
        Menu("Deplacer vers") {
            Button("Inbox") { state.move(ids: ids, toProject: nil) }
            Divider()
            ForEach(state.activeProjects) { p in
                Button(p.name) { state.move(ids: ids, toProject: p.id) }
            }
        }
        Divider()
        Button("Supprimer", role: .destructive) {
            for id in ids { state.run { try state.todos.delete(id) } }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: state.selection.systemImage).font(.system(size: 36)).foregroundStyle(.quaternary)
            Text(emptyMessage).foregroundStyle(.secondary)
            Text("⌘N pour ajouter une tache").font(.caption).foregroundStyle(.tertiary)
        }
    }

    private var emptyMessage: String {
        if !state.searchText.isEmpty { return "Aucun resultat" }
        switch state.selection {
        case .inbox: return "Inbox vide. Bien joue."
        case .today: return "Rien de prevu aujourd'hui."
        case .upcoming: return "Rien de planifie."
        case .anytime: return "Aucune tache en attente."
        case .someday: return "Rien pour plus tard."
        case .logbook: return "Le journal est vide."
        case .project: return "Projet vide."
        }
    }
}

struct ProjectHeaderView: View {
    @Environment(AppState.self) private var state
    let project: Project
    @State private var notes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ProjectProgressCircle(projectId: project.id, size: 22)
                Text(project.name).font(.title2.bold())
                Spacer()
                Button("Nouvel en-tete", systemImage: "text.insert") { state.newHeading(in: project.id) }
                    .labelStyle(.iconOnly).help("Ajouter un en-tete")
                Button("Terminer", systemImage: "checkmark.circle") { state.completeProject(project.id) }
                    .labelStyle(.iconOnly).help("Terminer le projet")
            }
            TextField("Notes", text: $notes, axis: .vertical)
                .textFieldStyle(.plain).foregroundStyle(.secondary).lineLimit(1...6)
                .onSubmit { commitNotes() }
                .onChange(of: notes) { _, _ in commitNotesDebounced() }
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 4)
        .onAppear { notes = project.notes }
        .onChange(of: project.id) { _, _ in notes = project.notes }
    }

    private func commitNotes() {
        guard notes != project.notes else { return }
        var p = project; p.notes = notes
        state.saveProject(p)
    }

    @State private var debounce: Task<Void, Never>?
    private func commitNotesDebounced() {
        debounce?.cancel()
        debounce = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if !Task.isCancelled { commitNotes() }
        }
    }
}
