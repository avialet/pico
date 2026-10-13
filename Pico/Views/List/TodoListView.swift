import SwiftUI
import VialetKit
import PicoCore

struct TodoListView: View {
    @Environment(AppState.self) private var state
    @FocusState private var listFocused: Bool

    private var accent: Color { state.selection.accent }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ListHeader()
                            .padding(.horizontal, 38)
                            .padding(.top, 50)
                            .padding(.bottom, 20)

                        if state.visibleTodos.isEmpty {
                            EmptyStateView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 70)
                        }

                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(state.sections) { section in
                                if section.title != nil {
                                    SectionHeader(section: section)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 22)
                                        .padding(.bottom, 6)
                                }
                                ForEach(section.todos) { todo in
                                    TodoRow(todo: todo, accent: accent)
                                        .id(todo.id)
                                        .dropDestination(for: String.self) { items, _ in
                                            guard let raw = items.first, raw.hasPrefix("todo:") else { return false }
                                            state.drop(EntityID(String(raw.dropFirst(5))), before: todo.id, in: section)
                                            return true
                                        }
                                }
                                if section.todos.isEmpty && section.title != nil {
                                    Text("Rien ici pour l'instant")
                                        .font(Theme.ui(12.5))
                                        .foregroundStyle(Theme.inkFaint)
                                        .padding(.leading, 50)
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                        .padding(.horizontal, 22)

                        Color.clear.frame(height: 130)
                    }
                    .frame(maxWidth: 820, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.automatic)
                .onChange(of: state.flashTodoId) { _, id in
                    guard let id else { return }
                    withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
                }
            }

            LinearGradient(colors: [Theme.paper.opacity(0), Theme.paper.opacity(0.92)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
                .allowsHitTesting(false)

            QuickAddBar(accent: accent)
                .frame(maxWidth: 720)
                .padding(.horizontal, 28)
                .padding(.bottom, 22)
        }
        .focusable()
        .focusEffectDisabled()
        .focused($listFocused)
        .onKeyPress(keys: [.upArrow, .downArrow, .return, .space, .escape]) { press in
            handleKey(press)
        }
        .onChange(of: state.selectedTodoIds) { _, ids in
            if !ids.isEmpty, state.editingTodoId == nil, !state.quickAddFocused { listFocused = true }
        }
        .animation(.snappy(duration: 0.28), value: state.visibleTodos.map(\.id))
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard state.editingTodoId == nil, !state.quickAddFocused else { return .ignored }
        switch press.key {
        case .upArrow:
            state.moveSelection(-1)
        case .downArrow:
            state.moveSelection(1)
        case .return:
            guard let id = state.selectedTodoIds.first else { return .ignored }
            state.editingTodoId = id
        case .space:
            guard !state.selectedTodoIds.isEmpty else { return .ignored }
            state.toggleComplete()
        case .escape:
            state.selectedTodoIds = []
        default:
            return .ignored
        }
        return .handled
    }
}

// MARK: - En-tete de liste

struct ListHeader: View {
    @Environment(AppState.self) private var state
    @State private var notes = ""
    @State private var notesTask: Task<Void, Never>?

    private var accent: Color { state.selection.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                titleIcon
                Text(title)
                    .font(Theme.listTitle(36))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Spacer()
                if let project = state.currentProject { projectActions(project) }
            }
            Text(tagline)
                .font(Theme.ui(13.5, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
            if state.selection == .today, state.searchText.isEmpty {
                LoadGauge(minutes: state.todayLoadMinutes, color: accent)
                    .padding(.top, 4)
            }
            if let project = state.currentProject {
                TextField("Ajouter des notes au projet…", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Theme.ui(13.5))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1...8)
                    .padding(.top, 4)
                    .onAppear { notes = project.notes }
                    .onChange(of: project.id) { _, _ in notes = project.notes }
                    .onChange(of: notes) { _, value in saveNotes(value, project: project) }
            }
        }
    }

    @ViewBuilder
    private var titleIcon: some View {
        if let project = state.currentProject {
            ProgressRing(fraction: state.projectProgress[project.id]?.fraction ?? 0, color: accent, size: 28, lineWidth: 3.5)
        } else if !state.searchText.isEmpty {
            Image(systemName: "magnifyingglass").font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.inkSoft)
        } else {
            Image(systemName: state.selection.systemImage)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(accent.gradient)
                .symbolEffect(.bounce, value: state.selection)
        }
    }

    private var title: String {
        if !state.searchText.isEmpty { return "« \(state.searchText) »" }
        return state.currentProject?.name ?? state.selection.title
    }

    private var tagline: String {
        let n = state.visibleTodos.count
        let tasks = n == 0 ? "aucune tâche" : n == 1 ? "1 tâche" : "\(n) tâches"
        if !state.searchText.isEmpty { return n == 0 ? "Aucun résultat" : "\(tasks) trouvée\(n > 1 ? "s" : "")" }
        switch state.selection {
        case .inbox: return "Tout ce qui attend d'être trié · \(tasks)"
        case .today: return "\(state.today.longLabel) · \(tasks)"
        case .upcoming: return "Ce qui arrive · \(tasks) planifiée\(n > 1 ? "s" : "")"
        case .anytime: return "Prêt quand vous l'êtes · \(tasks)"
        case .someday: return "Les idées qui mûrissent · \(tasks)"
        case .logbook: return "Ce qui est fait est fait · \(tasks)"
        case .project(let id):
            let t = state.projectProgress[id] ?? Tally(done: 0, total: 0)
            return "\(t.done) sur \(t.total) terminée\(t.done > 1 ? "s" : "")"
        }
    }

    private func projectActions(_ project: Project) -> some View {
        HStack(spacing: 8) {
            Button { state.newHeading(in: project.id) } label: {
                Label("Section", systemImage: "text.badge.plus")
            }
            Button { state.completeProject(project.id) } label: {
                Label("Terminer", systemImage: "checkmark.circle")
            }
        }
        .buttonStyle(.borderless)
        .font(Theme.ui(12.5, weight: .semibold))
        .foregroundStyle(accent)
    }

    private func saveNotes(_ value: String, project: Project) {
        notesTask?.cancel()
        notesTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, value != project.notes else { return }
            var p = project; p.notes = value
            state.saveProject(p)
        }
    }
}

// MARK: - En-tete de section

struct SectionHeader: View {
    @Environment(AppState.self) private var state
    let section: TodoSection

    var body: some View {
        if state.selection == .upcoming, let day = DayDate(isoString: section.id) {
            dayHeader(day)
        } else {
            plainHeader
        }
    }

    private func dayHeader(_ day: DayDate) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            Text("\(day.day)")
                .font(Theme.listTitle(30))
                .foregroundStyle(state.selection.accent)
                .frame(minWidth: 40, alignment: .trailing)
            VStack(alignment: .leading, spacing: 0) {
                Text(day.relativeLabel(today: state.today)).font(Theme.ui(14, weight: .bold)).foregroundStyle(Theme.ink)
                Text(day.weekdayLabel + " · " + day.monthLabel).font(Theme.ui(11.5)).foregroundStyle(Theme.inkSoft)
            }
            Rectangle().fill(Theme.line).frame(height: 1).padding(.bottom, 6)
        }
    }

    private var plainHeader: some View {
        let isLate = section.id == "late"
        let color = isLate ? Theme.coral : (section.id == "evening" ? Theme.lavender : Theme.inkSoft)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            if section.id == "evening" {
                Image(systemName: "moon.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(color)
            }
            Text((section.title ?? "").uppercased())
                .font(Theme.ui(11, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(color)
            if let subtitle = section.subtitle {
                Text(subtitle).font(Theme.ui(11.5)).foregroundStyle(Theme.inkFaint)
            }
            Rectangle().fill(Theme.line).frame(height: 1).padding(.bottom, 3)
            if isLate {
                Button("Tout ramener à aujourd'hui") {
                    state.plan(state.today, ids: Set(section.todos.map(\.id)))
                }
                .fixedSize()
                .buttonStyle(.plain)
                .font(Theme.ui(11.5, weight: .bold))
                .foregroundStyle(Theme.coral)
            }
        }
    }
}

// MARK: - Etat vide

struct EmptyStateView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 14) {
            HorizonIllustration(accent: state.selection.accent)
            Text(message.title).font(Theme.listTitle(22)).foregroundStyle(Theme.ink)
            Text(message.detail)
                .font(Theme.ui(13))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
    }

    private var message: (title: String, detail: String) {
        if !state.searchText.isEmpty { return ("Rien trouvé", "Essayez un autre mot, ou un numéro de ticket.") }
        switch state.selection {
        case .inbox: return ("Calme plat.", "Votre inbox est vide. Tapez une idée en bas, Pico la range pour vous.")
        case .today: return ("Journée libre.", "Rien de prévu aujourd'hui. Ajoutez « … aujourd'hui » ou glissez une tâche ici.")
        case .upcoming: return ("Horizon dégagé.", "Rien de planifié. Essayez « vendredi 10h » ou « dans 3 jours ».")
        case .anytime: return ("Rien en attente.", "Les tâches sans date atterrissent ici.")
        case .someday: return ("Pas de rêveries.", "Notez ici ce qui peut attendre : « … un jour ».")
        case .logbook: return ("Page blanche.", "Les tâches terminées viendront s'écrire ici.")
        case .project: return ("Projet tout neuf.", "Ajoutez la première tâche en bas, ou une section avec le bouton en haut.")
        }
    }
}
