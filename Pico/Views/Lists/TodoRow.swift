import SwiftUI
import PicoCore

struct TodoRow: View {
    @Environment(AppState.self) private var state
    let todo: Todo
    var focused: FocusState<EntityID?>.Binding
    @State private var title = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button {
                state.toggleComplete([todo.id])
            } label: {
                Image(systemName: todo.status == .open ? "circle" : (todo.status == .done ? "checkmark.circle.fill" : "xmark.circle"))
                    .font(.system(size: 15))
                    .foregroundStyle(todo.status == .open ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
            }
            .buttonStyle(.plain)

            if state.editingTodoId == todo.id {
                TextField("Titre", text: $title)
                    .textFieldStyle(.plain)
                    .focused(focused, equals: todo.id)
                    .onSubmit { commit() }
                    .onExitCommand { title = todo.title; state.editingTodoId = nil }
                    .onChange(of: focused.wrappedValue) { _, new in if new != todo.id { commit() } }
                    .onAppear { title = todo.title }
            } else {
                Text(todo.title)
                    .strikethrough(todo.status != .open)
                    .foregroundStyle(todo.status == .open ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)
            badges
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var badges: some View {
        HStack(spacing: 6) {
            if todo.priority >= 2 {
                Image(systemName: todo.priority == 3 ? "exclamationmark.2" : "exclamationmark")
                    .foregroundStyle(.orange).font(.caption)
            }
            if todo.source != nil {
                Image(systemName: "link").foregroundStyle(.secondary).font(.caption)
            }
            if state.selection != .project(todo.projectId ?? "") , let p = state.project(todo.projectId) {
                Text(p.name).font(.caption).foregroundStyle(.secondary)
            }
            if let t = todo.plannedTime {
                Text(t.timeLabel).font(.caption).foregroundStyle(.secondary)
            }
            if let d = todo.durationMinutes {
                Text(d.durationLabel).font(.caption).foregroundStyle(.tertiary)
            }
            if case .upcoming = state.selection {} else if let planned = todo.plannedDate, state.selection != .today {
                Label(planned.relativeLabel(today: state.today), systemImage: "star")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let due = todo.dueDate {
                Label(due.relativeLabel(today: state.today), systemImage: "flag")
                    .font(.caption)
                    .foregroundStyle(due.isPast && todo.status == .open ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
            }
        }
    }

    private func commit() {
        guard state.editingTodoId == todo.id else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != todo.title {
            var t = todo; t.title = trimmed
            state.save(t)
        }
        state.editingTodoId = nil
    }
}
