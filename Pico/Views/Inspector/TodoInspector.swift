import SwiftUI
import PicoCore

/// Detail de la tache selectionnee. Chaque modification est sauvegardee.
struct TodoInspector: View {
    @Environment(AppState.self) private var state

    var body: some View {
        if state.selectedTodoIds.count == 1, let id = state.selectedTodoIds.first, let todo = state.todo(id) {
            TodoEditor(todo: todo)
                .id(todo.id)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "sidebar.trailing").font(.largeTitle).foregroundStyle(.quaternary)
                Text(state.selectedTodoIds.count > 1 ? "\(state.selectedTodoIds.count) taches selectionnees" : "Aucune tache selectionnee")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct TodoEditor: View {
    @Environment(AppState.self) private var state
    @State private var draft: Todo
    @State private var checklist: [ChecklistItem] = []
    @State private var todoTags: [Tag] = []
    @State private var newChecklistTitle = ""
    @State private var newTagName = ""
    @State private var saveTask: Task<Void, Never>?

    let todo: Todo
    init(todo: Todo) { self.todo = todo; _draft = State(initialValue: todo) }

    var body: some View {
        Form {
            Section {
                TextField("Titre", text: $draft.title)
                    .font(.title3)
                TextField("Notes (Markdown)", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...12)
            }

            Section("Quand") {
                Picker("Prevu", selection: plannedKind) {
                    Text("A tout moment").tag(PlannedKind.anytime)
                    Text("Aujourd'hui").tag(PlannedKind.today)
                    Text("Demain").tag(PlannedKind.tomorrow)
                    Text("Date...").tag(PlannedKind.date)
                    Text("Un jour").tag(PlannedKind.someday)
                }
                if draft.plannedDate != nil {
                    DatePicker("Jour", selection: plannedDateBinding, displayedComponents: .date)
                    Picker("Moment", selection: $draft.plannedSlot) {
                        Text("Journee").tag(PlannedSlot.day)
                        Text("Soir").tag(PlannedSlot.evening)
                    }
                    Toggle("Heure fixe", isOn: Binding(
                        get: { draft.plannedTime != nil },
                        set: { draft.plannedTime = $0 ? 9 * 60 : nil }))
                    if draft.plannedTime != nil {
                        DatePicker("Heure", selection: plannedTimeBinding, displayedComponents: .hourAndMinute)
                    }
                }
                Toggle("Echeance", isOn: Binding(
                    get: { draft.dueDate != nil },
                    set: { draft.dueDate = $0 ? (draft.plannedDate ?? state.today) : nil }))
                if draft.dueDate != nil {
                    DatePicker("Date limite", selection: dueDateBinding, displayedComponents: .date)
                }
                Picker("Repeter", selection: recurrenceBinding) {
                    Text("Jamais").tag("")
                    Text("Chaque jour").tag("FREQ=DAILY")
                    Text("Jours ouvres").tag("FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR")
                    Text("Chaque semaine").tag("FREQ=WEEKLY")
                    Text("Toutes les 2 semaines").tag("FREQ=WEEKLY;INTERVAL=2")
                    Text("Chaque mois").tag("FREQ=MONTHLY")
                    Text("Chaque annee").tag("FREQ=YEARLY")
                    Text("3 jours apres achevement").tag("FREQ=DAILY;INTERVAL=3;BASIS=COMPLETION")
                    Text("1 semaine apres achevement").tag("FREQ=WEEKLY;BASIS=COMPLETION")
                }
            }

            Section("Organisation") {
                Picker("Projet", selection: $draft.projectId) {
                    Text("Aucun (Inbox)").tag(EntityID?.none)
                    ForEach(state.activeProjects) { p in Text(p.name).tag(EntityID?.some(p.id)) }
                }
                Picker("Priorite", selection: $draft.priority) {
                    Text("Normale").tag(0); Text("Basse").tag(1); Text("Haute").tag(2); Text("Urgente").tag(3)
                }
                Picker("Duree", selection: $draft.durationMinutes) {
                    Text("Non estimee").tag(Int?.none)
                    ForEach([15, 30, 45, 60, 90, 120, 180, 240], id: \.self) { m in
                        Text(m.durationLabel).tag(Int?.some(m))
                    }
                }
                tagsEditor
            }

            Section("Checklist") {
                ForEach(checklist) { item in
                    Toggle(isOn: Binding(get: { item.isDone }, set: { done in
                        state.run { try state.todos.setChecklistItem(item.id, done: done) }
                        reloadRelated()
                    })) {
                        Text(item.title).strikethrough(item.isDone)
                    }
                }
                TextField("Ajouter un element", text: $newChecklistTitle)
                    .onSubmit {
                        let t = newChecklistTitle.trimmingCharacters(in: .whitespaces)
                        guard !t.isEmpty else { return }
                        state.run { try state.todos.addChecklistItem(t, to: draft.id) }
                        newChecklistTitle = ""
                        reloadRelated()
                    }
            }

            if let url = draft.externalURL, let link = URL(string: url) {
                Section("Origine") {
                    LabeledContent(draft.source?.capitalized ?? "Lien") {
                        Link(draft.externalKey ?? url, destination: link)
                    }
                }
            }

            Section {
                LabeledContent("Creee") { Text(draft.createdAt, style: .date) }
                if let done = draft.completedAt { LabeledContent("Terminee") { Text(done, style: .date) } }
                Button(draft.status == .open ? "Terminer" : "Rouvrir") { state.toggleComplete([draft.id]) }
                Button("Supprimer", role: .destructive) { state.run { try state.todos.delete(draft.id) } }
            }
        }
        .formStyle(.grouped)
        .onAppear { reloadRelated() }
        .onChange(of: draft) { _, new in
            if !new.editableFieldsEqual(todo) { scheduleSave(new) }
        }
        .onChange(of: todo) { _, new in
            // Modification venue d'ailleurs (liste, CLI) : on resynchronise le brouillon.
            if saveTask == nil || saveTask!.isCancelled, !new.editableFieldsEqual(draft) { draft = new }
            reloadRelated()
        }
    }

    // MARK: Tags

    private var tagsEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !todoTags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(todoTags) { tag in
                        HStack(spacing: 2) {
                            Text(tag.name).font(.caption)
                            Button { setTags(todoTags.filter { $0.id != tag.id }) } label: {
                                Image(systemName: "xmark").font(.system(size: 8))
                            }.buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: Capsule())
                    }
                }
            }
            TextField("Ajouter un tag", text: $newTagName)
                .onSubmit {
                    let n = newTagName.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    if let tag = try? state.tags.findOrCreate(n) { setTags(todoTags + [tag]) }
                    newTagName = ""
                }
        }
    }

    private func setTags(_ tags: [Tag]) {
        state.run { try state.todos.setTags(tags.map(\.id), on: draft.id) }
        reloadRelated()
    }

    private func reloadRelated() {
        checklist = (try? state.todos.checklist(of: draft.id)) ?? []
        todoTags = (try? state.todos.tags(of: draft.id)) ?? []
    }

    // MARK: Sauvegarde

    private func scheduleSave(_ todo: Todo) {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            var t = todo
            t.title = t.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.title.isEmpty { state.save(t) }
            saveTask = nil
        }
    }

    // MARK: Bindings

    enum PlannedKind: Hashable { case anytime, today, tomorrow, date, someday }

    private var plannedKind: Binding<PlannedKind> {
        Binding(get: {
            if draft.isSomeday { return .someday }
            guard let d = draft.plannedDate else { return .anytime }
            if d == state.today { return .today }
            if d == state.today.adding(days: 1) { return .tomorrow }
            return .date
        }, set: { kind in
            draft.isSomeday = false
            switch kind {
            case .anytime: draft.plannedDate = nil
            case .today: draft.plannedDate = state.today
            case .tomorrow: draft.plannedDate = state.today.adding(days: 1)
            case .date: draft.plannedDate = draft.plannedDate ?? state.today
            case .someday: draft.plannedDate = nil; draft.isSomeday = true
            }
            if kind != .anytime { draft.isInbox = false }
        })
    }

    private var plannedDateBinding: Binding<Date> {
        Binding(get: { (draft.plannedDate ?? state.today).date(atMinutes: 12 * 60) },
                set: { draft.plannedDate = DayDate($0) })
    }
    private var dueDateBinding: Binding<Date> {
        Binding(get: { (draft.dueDate ?? state.today).date(atMinutes: 12 * 60) },
                set: { draft.dueDate = DayDate($0) })
    }
    private var plannedTimeBinding: Binding<Date> {
        Binding(get: { state.today.date(atMinutes: draft.plannedTime ?? 9 * 60) },
                set: { d in
                    let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                    draft.plannedTime = (c.hour ?? 9) * 60 + (c.minute ?? 0)
                })
    }
    private var recurrenceBinding: Binding<String> {
        Binding(get: { draft.recurrenceRule ?? "" }, set: { draft.recurrenceRule = $0.isEmpty ? nil : $0 })
    }
}

extension Todo {
    /// Egalite des champs modifiables par l'utilisateur (ignore les horodatages).
    func editableFieldsEqual(_ o: Todo) -> Bool {
        title == o.title && notes == o.notes && projectId == o.projectId && headingId == o.headingId
            && priority == o.priority && plannedDate == o.plannedDate && plannedSlot == o.plannedSlot
            && plannedTime == o.plannedTime && dueDate == o.dueDate && durationMinutes == o.durationMinutes
            && recurrenceRule == o.recurrenceRule && isSomeday == o.isSomeday && status == o.status
    }
}
