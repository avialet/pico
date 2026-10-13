import SwiftUI
import VialetKit
import PicoCore

/// Panneau flottant de detail de la tache selectionnee.
struct InspectorPanel: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            if let id = state.selectedTodoIds.first, state.selectedTodoIds.count == 1, let todo = state.todo(id) {
                TodoEditor(todo: todo).id(todo.id)
            } else {
                MultiSelectionSummary()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.card)
                .shadow(color: .black.opacity(0.10), radius: 24, y: 10)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct MultiSelectionSummary: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let ids = state.selectedTodoIds
        VStack(alignment: .leading, spacing: 16) {
            Text("\(ids.count) tâches").font(Theme.listTitle(24)).foregroundStyle(Theme.ink)
            Text("Actions groupées").font(Theme.ui(12, weight: .bold)).foregroundStyle(Theme.inkSoft)
            FlowLayout(spacing: 6) {
                ChipButton("Aujourd'hui", icon: "sun.max.fill", color: Theme.sun, selected: false) { state.plan(state.today, ids: ids) }
                ChipButton("Demain", icon: "sunrise.fill", color: Theme.sun, selected: false) { state.plan(state.today.adding(days: 1), ids: ids) }
                ChipButton("Un jour", icon: "moon.stars.fill", color: Theme.lavender, selected: false) { state.moveToSomeday(ids: ids) }
                ChipButton("Terminer", icon: "checkmark", color: Theme.pine, selected: false) { state.toggleComplete(ids) }
                ChipButton("Supprimer", icon: "trash", color: Theme.danger, selected: false) { state.delete(ids: ids) }
            }
            Spacer()
        }
        .padding(22)
    }
}

struct TodoEditor: View {
    @Environment(AppState.self) private var state
    let todo: Todo
    @State private var draft: Todo
    @State private var checklist: [ChecklistItem] = []
    @State private var newChecklistTitle = ""
    @State private var newTagName = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var pickingPlanned = false
    @State private var pickingDue = false

    init(todo: Todo) {
        self.todo = todo
        _draft = State(initialValue: todo)
    }

    private var accent: Color { draft.projectId.map(Theme.color(for:)) ?? state.selection.accent }
    private var todoTags: [Tag] { state.tagsByTodo[draft.id] ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                when
                due
                repeatSection
                organisation
                tagsSection
                checklistSection
                origin
                footer
            }
            .padding(22)
        }
        .scrollIndicators(.never)
        .onAppear { reloadChecklist() }
        .onChange(of: draft) { _, new in
            if !new.editableFieldsEqual(todo) { scheduleSave(new) }
        }
        .onChange(of: todo) { _, new in
            if saveTask == nil, !new.editableFieldsEqual(draft) { draft = new }
            reloadChecklist()
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                CheckCircle(checked: draft.status != .open, color: accent, size: 22) { state.toggleComplete([draft.id]) }
                    .padding(.top, 3)
                TextField("Titre", text: $draft.title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Theme.listTitle(21))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1...4)
            }
            TextField("Notes, liens, contexte…", text: $draft.notes, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.ui(13.5))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(2...14)
                .padding(.leading, 32)
        }
    }

    private var when: some View {
        group("Quand", icon: "sun.max.fill", color: Theme.sun) {
            FlowLayout(spacing: 6) {
                ChipButton("Aujourd'hui", icon: "sun.max.fill", color: Theme.sun,
                           selected: draft.plannedDate == state.today && draft.plannedSlot == .day) { setPlanned(state.today, .day) }
                ChipButton("Ce soir", icon: "moon.fill", color: Theme.lavender,
                           selected: draft.plannedDate == state.today && draft.plannedSlot == .evening) { setPlanned(state.today, .evening) }
                ChipButton("Demain", icon: "sunrise.fill", color: Theme.sun,
                           selected: draft.plannedDate == state.today.adding(days: 1)) { setPlanned(state.today.adding(days: 1), .day) }
                ChipButton("Week-end", icon: "beach.umbrella.fill", color: Theme.coral,
                           selected: draft.plannedDate == weekend) { setPlanned(weekend, .day) }
                ChipButton("Lundi", icon: "briefcase.fill", color: Theme.sea,
                           selected: draft.plannedDate == nextMonday) { setPlanned(nextMonday, .day) }
                ChipButton(customDateLabel, icon: "calendar", color: Theme.coral, selected: isCustomDate) { pickingPlanned = true }
                    .popover(isPresented: $pickingPlanned) { datePopover(selection: plannedDateBinding) }
                ChipButton("Un jour", icon: "moon.stars.fill", color: Theme.lavender, selected: draft.isSomeday) {
                    draft.plannedDate = nil; draft.isSomeday = true; draft.isInbox = false
                }
                ChipButton("Sans date", icon: "circle.dashed", color: Theme.stone,
                           selected: draft.plannedDate == nil && !draft.isSomeday) {
                    draft.plannedDate = nil; draft.isSomeday = false
                }
            }
            if draft.plannedDate != nil {
                HStack(spacing: 8) {
                    if draft.plannedTime != nil {
                        DatePicker("", selection: plannedTimeBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .fixedSize()
                        Button { draft.plannedTime = nil } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(Theme.inkFaint)
                    } else {
                        ChipButton("Ajouter une heure", icon: "clock", color: Theme.sun, selected: false) {
                            draft.plannedTime = 9 * 60
                        }
                    }
                }
            }
        }
    }

    private var due: some View {
        group("Échéance", icon: "flag.fill", color: Theme.coral) {
            HStack(spacing: 6) {
                if let d = draft.dueDate {
                    ChipButton(d.relativeLabel(today: state.today), icon: "flag.fill",
                               color: d <= state.today ? Theme.danger : Theme.coral, selected: true) { pickingDue = true }
                        .popover(isPresented: $pickingDue) { datePopover(selection: dueDateBinding) }
                    Button { draft.dueDate = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(Theme.inkFaint)
                } else {
                    ChipButton("Ajouter une échéance", icon: "plus", color: Theme.coral, selected: false) { pickingDue = true }
                        .popover(isPresented: $pickingDue) { datePopover(selection: dueDateBinding) }
                }
            }
        }
    }

    private var repeatSection: some View {
        group("Répéter", icon: "repeat", color: Theme.pine) {
            Menu {
                Button("Jamais") { draft.recurrenceRule = nil }
                Divider()
                ForEach(Self.recurrenceOptions, id: \.self) { rule in
                    Button(RecurrenceRule(string: rule)?.label ?? rule) { draft.recurrenceRule = rule }
                }
            } label: {
                Chip(draft.recurrence?.label ?? "Jamais", icon: "repeat",
                     color: draft.recurrence == nil ? Theme.inkSoft : Theme.pine, filled: draft.recurrence != nil)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private static let recurrenceOptions = [
        "FREQ=DAILY", "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR", "FREQ=WEEKLY", "FREQ=WEEKLY;INTERVAL=2",
        "FREQ=MONTHLY", "FREQ=YEARLY", "FREQ=DAILY;INTERVAL=3;BASIS=COMPLETION", "FREQ=WEEKLY;BASIS=COMPLETION",
    ]

    private var organisation: some View {
        group("Organisation", icon: "folder.fill", color: Theme.sea) {
            VStack(alignment: .leading, spacing: 10) {
                Menu {
                    Button("Aucun (Inbox)") { draft.projectId = nil; draft.headingId = nil }
                    Divider()
                    ForEach(state.activeProjects) { p in
                        Button(p.name) { draft.projectId = p.id; draft.headingId = nil; draft.isInbox = false }
                    }
                } label: {
                    let p = state.project(draft.projectId)
                    Chip(p?.name ?? "Aucun projet", icon: "folder.fill",
                         color: p.map { Theme.color(for: $0.id) } ?? Theme.inkSoft, filled: p != nil)
                }
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()

                FlowLayout(spacing: 6) {
                    ForEach([(0, "Normale"), (2, "Importante"), (3, "Urgente")], id: \.0) { value, label in
                        ChipButton(label, icon: value == 0 ? "minus" : "exclamationmark",
                                   color: value == 3 ? Theme.danger : value == 2 ? Theme.sun : Theme.stone,
                                   selected: draft.priority == value || (value == 0 && draft.priority == 1)) {
                            draft.priority = value
                        }
                    }
                }
                FlowLayout(spacing: 6) {
                    ForEach([15, 30, 60, 120, 240], id: \.self) { m in
                        ChipButton(m.durationLabel, icon: nil, color: Theme.stone, selected: draft.durationMinutes == m) {
                            draft.durationMinutes = draft.durationMinutes == m ? nil : m
                        }
                    }
                }
            }
        }
    }

    private var tagsSection: some View {
        group("Tags", icon: "tag.fill", color: Theme.lavender) {
            FlowLayout(spacing: 6) {
                ForEach(todoTags) { tag in
                    HStack(spacing: 4) {
                        Text(tag.name).font(Theme.ui(12, weight: .semibold))
                        Button { setTags(todoTags.filter { $0.id != tag.id }) } label: {
                            Image(systemName: "xmark").font(.system(size: 8, weight: .heavy))
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .foregroundStyle(.white)
                    .background(Capsule().fill(Theme.color(for: tag.id).gradient))
                }
                TextField("+ tag", text: $newTagName)
                    .textFieldStyle(.plain)
                    .font(Theme.ui(12.5))
                    .frame(width: 80)
                    .onSubmit {
                        let name = newTagName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty, let tag = try? state.tags.findOrCreate(name) else { return }
                        setTags(todoTags + [tag])
                        newTagName = ""
                    }
            }
        }
    }

    private var checklistSection: some View {
        group("Checklist", icon: "checklist", color: Theme.pine) {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(checklist) { item in
                    HStack(spacing: 9) {
                        CheckCircle(checked: item.isDone, color: Theme.pine, size: 16) {
                            state.run { try state.todos.setChecklistItem(item.id, done: !item.isDone) }
                            reloadChecklist()
                        }
                        Text(item.title)
                            .font(Theme.ui(13))
                            .foregroundStyle(item.isDone ? Theme.inkSoft : Theme.ink)
                            .strikethrough(item.isDone, color: Theme.inkFaint)
                    }
                }
                HStack(spacing: 9) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.inkFaint)
                        .frame(width: 16)
                    TextField("Ajouter une étape", text: $newChecklistTitle)
                        .textFieldStyle(.plain)
                        .font(Theme.ui(13))
                        .onSubmit {
                            let t = newChecklistTitle.trimmingCharacters(in: .whitespaces)
                            guard !t.isEmpty else { return }
                            state.run { try state.todos.addChecklistItem(t, to: draft.id) }
                            newChecklistTitle = ""
                            reloadChecklist()
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var origin: some View {
        if let raw = draft.externalURL, let url = URL(string: raw) {
            group("Origine", icon: "link", color: Theme.sea) {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Text((draft.source ?? "lien").uppercased()).font(Theme.ui(10.5, weight: .heavy)).tracking(0.8)
                        Text(draft.externalKey ?? raw).font(Theme.ui(12.5, weight: .semibold)).lineLimit(1)
                        Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Theme.sea)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Créée le \(draft.createdAt.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "fr_FR"))))")
                .font(Theme.ui(11.5))
                .foregroundStyle(Theme.inkFaint)
            Spacer()
            Button(role: .destructive) { state.delete(ids: [draft.id]) } label: {
                Image(systemName: "trash").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.inkFaint)
            .help("Supprimer la tâche")
        }
        .padding(.top, 6)
    }

    // MARK: Aides

    private func group<Content: View>(_ title: String, icon: String, color: Color,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundStyle(color)
                Text(title.uppercased()).font(Theme.ui(10.5, weight: .heavy)).tracking(1).foregroundStyle(Theme.inkSoft)
            }
            content()
        }
    }

    private func datePopover(selection: Binding<Date>) -> some View {
        DatePicker("", selection: selection, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "fr_FR"))
            .padding(12)
    }

    private var weekend: DayDate { state.today.startOfWeek.adding(days: 5) }
    private var nextMonday: DayDate { state.today.startOfWeek.adding(days: 7) }

    private var isCustomDate: Bool {
        guard let d = draft.plannedDate else { return false }
        return ![state.today, state.today.adding(days: 1), weekend, nextMonday].contains(d)
    }

    private var customDateLabel: String {
        isCustomDate ? draft.plannedDate!.relativeLabel(today: state.today) : "Date…"
    }

    private func setPlanned(_ date: DayDate, _ slot: PlannedSlot) {
        draft.plannedDate = date
        draft.plannedSlot = slot
        draft.isSomeday = false
        draft.isInbox = false
    }

    private func setTags(_ tags: [Tag]) {
        state.run { try state.todos.setTags(tags.map(\.id), on: draft.id) }
    }

    private func reloadChecklist() {
        checklist = (try? state.todos.checklist(of: draft.id)) ?? []
    }

    private func scheduleSave(_ value: Todo) {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            var t = value
            t.title = t.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.title.isEmpty { state.save(t) }
            saveTask = nil
        }
    }

    private var plannedDateBinding: Binding<Date> {
        Binding(get: { (draft.plannedDate ?? state.today).date(atMinutes: 12 * 60) },
                set: { setPlanned(DayDate($0), draft.plannedSlot); pickingPlanned = false })
    }

    private var dueDateBinding: Binding<Date> {
        Binding(get: { (draft.dueDate ?? state.today).date(atMinutes: 12 * 60) },
                set: { draft.dueDate = DayDate($0); pickingDue = false })
    }

    private var plannedTimeBinding: Binding<Date> {
        Binding(get: { state.today.date(atMinutes: draft.plannedTime ?? 9 * 60) },
                set: { d in
                    let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                    draft.plannedTime = (c.hour ?? 9) * 60 + (c.minute ?? 0)
                })
    }
}

extension Todo {
    /// Egalite des champs modifiables (ignore les horodatages).
    func editableFieldsEqual(_ o: Todo) -> Bool {
        title == o.title && notes == o.notes && projectId == o.projectId && headingId == o.headingId
            && priority == o.priority && plannedDate == o.plannedDate && plannedSlot == o.plannedSlot
            && plannedTime == o.plannedTime && dueDate == o.dueDate && durationMinutes == o.durationMinutes
            && recurrenceRule == o.recurrenceRule && isSomeday == o.isSomeday && status == o.status
    }
}
