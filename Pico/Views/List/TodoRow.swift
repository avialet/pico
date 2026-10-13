import SwiftUI
import VialetKit
import PicoCore

/// Une tache, en carte arrondie.
struct TodoRow: View {
    @Environment(AppState.self) private var state
    let todo: Todo
    let accent: Color
    @State private var hovering = false
    @State private var completing = false
    @State private var flash = false
    @State private var title = ""
    @FocusState private var titleFocused: Bool

    private var isSelected: Bool { state.selectedTodoIds.contains(todo.id) }
    private var isEditing: Bool { state.editingTodoId == todo.id }
    private var isDone: Bool { todo.status != .open }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CheckCircle(checked: isDone || completing, color: todo.priority == 3 ? Theme.danger : accent) { complete() }
            VStack(alignment: .leading, spacing: 4) {
                titleView
                if hasMeta { metaLine }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, hasMeta ? 9 : 11)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? accent.opacity(0.45) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .opacity(completing ? 0.55 : 1)
        .scaleEffect(completing ? 0.985 : 1)
        .onHover { hovering = $0 }
        .onTapGesture { handleTap() }
        .draggable("todo:" + todo.id.rawValue) {
            Chip(todo.title, icon: "circle", color: accent, filled: true)
        }
        .contextMenu { TodoContextMenu(ids: state.selectedTodoIds.contains(todo.id) ? state.selectedTodoIds : [todo.id]) }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .onAppear { if state.flashTodoId == todo.id { pulse() } }
        .onChange(of: state.flashTodoId) { _, id in if id == todo.id { pulse() } }
        .onChange(of: isEditing) { _, editing in
            if editing { title = todo.title; titleFocused = true }
        }
    }

    // MARK: Parties

    @ViewBuilder
    private var titleView: some View {
        if isEditing {
            TextField("Titre", text: $title)
                .textFieldStyle(.plain)
                .font(Theme.ui(14.5, weight: .medium))
                .focused($titleFocused)
                .onSubmit { commit() }
                .onExitCommand { state.editingTodoId = nil }
                .onChange(of: titleFocused) { _, focused in if !focused { commit() } }
        } else {
            Text(todo.title)
                .font(Theme.ui(14.5, weight: .medium))
                .foregroundStyle(isDone ? Theme.inkSoft : Theme.ink)
                .strikethrough(isDone, color: Theme.inkFaint)
                .lineLimit(2)
        }
    }

    private var hasMeta: Bool {
        projectToShow != nil || !(state.tagsByTodo[todo.id] ?? []).isEmpty || state.checklistTally[todo.id] != nil
            || !todo.notes.isEmpty || todo.recurrence != nil || todo.source != nil || showPlannedDate
    }

    private var projectToShow: Project? {
        if case .project = state.selection { return nil }
        return state.project(todo.projectId)
    }

    private var showPlannedDate: Bool {
        guard let planned = todo.plannedDate else { return false }
        switch state.selection {
        case .today: return planned < state.today
        case .upcoming: return false
        default: return true
        }
    }

    private var metaLine: some View {
        HStack(spacing: 8) {
            if let p = projectToShow {
                HStack(spacing: 4) {
                    Circle().fill(Theme.color(for: p.id)).frame(width: 6, height: 6)
                    Text(p.name)
                }
                .font(Theme.ui(11.5, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
            }
            if showPlannedDate, let planned = todo.plannedDate {
                Label(planned.relativeLabel(today: state.today), systemImage: "sun.max")
                    .font(Theme.ui(11.5, weight: .medium))
                    .foregroundStyle(planned < state.today ? Theme.coral : Theme.inkSoft)
            }
            if let tally = state.checklistTally[todo.id] {
                Label("\(tally.done)/\(tally.total)", systemImage: "checklist")
                    .font(Theme.ui(11.5, weight: .medium))
                    .foregroundStyle(tally.done == tally.total ? Theme.pine : Theme.inkSoft)
            }
            if let rule = todo.recurrence {
                Image(systemName: "repeat").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.inkSoft)
                    .help(rule.label)
            }
            if !todo.notes.isEmpty {
                Image(systemName: "text.alignleft").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.inkFaint)
            }
            if let source = todo.source {
                Chip((todo.externalKey ?? source).uppercased(), icon: "link", color: Theme.sea)
            }
            ForEach(state.tagsByTodo[todo.id] ?? []) { tag in
                Chip(tag.name, color: Theme.color(for: tag.id))
            }
        }
        .labelStyle(TightLabelStyle())
    }

    @ViewBuilder
    private var trailing: some View {
        HStack(spacing: 6) {
            if todo.priority >= 2 {
                Text(todo.priority == 3 ? "!!" : "!")
                    .font(Theme.ui(13, weight: .heavy))
                    .foregroundStyle(todo.priority == 3 ? Theme.danger : Theme.sun)
            }
            if let time = todo.plannedTime {
                Chip(time.timeLabel, icon: "clock", color: Theme.inkSoft)
            }
            if let minutes = todo.durationMinutes {
                Chip(minutes.durationLabel, icon: "hourglass", color: Theme.inkSoft)
            }
            if let due = todo.dueDate {
                let urgent = due <= state.today && !isDone
                Chip(due.relativeLabel(today: state.today), icon: "flag.fill",
                     color: urgent ? Theme.danger : Theme.coral, filled: urgent)
            }
            if isDone, let completed = todo.completedAt {
                Text(completed, format: .dateTime.day().month(.abbreviated))
                    .font(Theme.ui(11.5))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isSelected ? AnyShapeStyle(accent.opacity(0.13))
                  : flash ? AnyShapeStyle(accent.opacity(0.22))
                  : hovering ? AnyShapeStyle(Theme.card.opacity(0.9))
                  : AnyShapeStyle(Color.clear))
            .shadow(color: .black.opacity(hovering && !isSelected ? 0.05 : 0), radius: 6, y: 2)
    }

    // MARK: Actions

    private func handleTap() {
        let event = NSApp.currentEvent
        if (event?.clickCount ?? 1) >= 2 {
            state.select(todo.id)
            state.editingTodoId = todo.id
            return
        }
        let flags = event?.modifierFlags ?? []
        state.select(todo.id, extend: flags.contains(.command), range: flags.contains(.shift))
        if state.editingTodoId != todo.id { state.editingTodoId = nil }
    }

    /// Coche avec un temps de grace (comme Things) avant de quitter la liste.
    private func complete() {
        if isDone { state.toggleComplete([todo.id]); return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { completing = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.snappy) { state.toggleComplete([todo.id]) }
            completing = false
        }
    }

    private func commit() {
        guard isEditing else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != todo.title {
            var t = todo; t.title = trimmed
            state.save(t)
        }
        state.editingTodoId = nil
    }

    private func pulse() {
        withAnimation(.easeOut(duration: 0.2)) { flash = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeOut(duration: 0.6)) { flash = false }
            if state.flashTodoId == todo.id { state.flashTodoId = nil }
        }
    }
}

struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.font(.system(size: 9.5, weight: .bold))
            configuration.title
        }
    }
}

/// Menu contextuel commun (ligne, selection multiple).
struct TodoContextMenu: View {
    @Environment(AppState.self) private var state
    let ids: Set<EntityID>

    var body: some View {
        Button("Terminer / rouvrir") { state.toggleComplete(ids) }
        Menu("Prévoir") {
            Button("Aujourd'hui") { state.plan(state.today, ids: ids) }
            Button("Ce soir") { state.plan(state.today, slot: .evening, ids: ids) }
            Button("Demain") { state.plan(state.today.adding(days: 1), ids: ids) }
            Button("Ce week-end") { state.plan(state.today.startOfWeek.adding(days: 5), ids: ids) }
            Button("Lundi prochain") { state.plan(state.today.startOfWeek.adding(days: 7), ids: ids) }
            Divider()
            Button("À tout moment") { state.plan(nil, ids: ids) }
            Button("Un jour") { state.moveToSomeday(ids: ids) }
        }
        Menu("Déplacer vers") {
            Button("Inbox") { state.move(ids: ids, toProject: nil) }
            Divider()
            ForEach(state.activeProjects) { p in
                Button(p.name) { state.move(ids: ids, toProject: p.id) }
            }
        }
        Divider()
        Button("Supprimer", role: .destructive) { state.delete(ids: ids) }
    }
}
