import SwiftUI
import PicoCore

/// Barre de saisie flottante : une ligne en langage naturel, analysee en direct.
struct QuickAddBar: View {
    @Environment(AppState.self) private var state
    let accent: Color
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        let parsed = state.parser.parse(text)
        VStack(alignment: .leading, spacing: 10) {
            if focused && !text.isEmpty {
                ParsedPreview(parsed: parsed, accent: accent)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(accent.gradient))
                    .rotationEffect(.degrees(focused ? 90 : 0))
                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.inkFaint))
                    .textFieldStyle(.plain)
                    .font(Theme.ui(15, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .focused($focused)
                    .onSubmit { submit(parsed) }
                    .onExitCommand { text = ""; focused = false }
                if focused {
                    Text("↩︎ ajouter")
                        .font(Theme.ui(11, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                } else {
                    Text("⌘N").font(Theme.ui(11, weight: .bold)).foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.card)
                .shadow(color: .black.opacity(focused ? 0.16 : 0.08), radius: focused ? 22 : 12, y: focused ? 10 : 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(focused ? accent.opacity(0.5) : Theme.line, lineWidth: 1)
        )
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: focused)
        .animation(.snappy(duration: 0.2), value: text.isEmpty)
        .onChange(of: focused) { _, value in state.quickAddFocused = value }
        .onChange(of: text) { _, value in
            // Coller plusieurs lignes = une tache par ligne.
            guard value.contains(where: \.isNewline) else { return }
            let lines = value.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \t-*•☐[]")) }
                .filter { !$0.isEmpty }
            text = ""
            withAnimation(.snappy) {
                for line in lines { state.quickAdd(state.parser.parse(line)) }
            }
        }
        .onChange(of: state.quickAddFocusRequest) { _, _ in focused = true }
    }

    private var placeholder: String {
        switch state.selection {
        case .today: "Ajouter à aujourd'hui… essayez « appeler le fournisseur 14h @urgent »"
        case .upcoming: "Planifier… essayez « revue sprint vendredi 10h ~1h »"
        case .project: "Ajouter au projet… essayez « livrer la maquette pour jeudi »"
        default: "Ajouter une tâche… essayez « relancer devis demain #Infra »"
        }
    }

    private func submit(_ parsed: ParsedEntry) {
        guard !parsed.title.isEmpty else { return }
        withAnimation(.snappy) { state.quickAdd(parsed) }
        text = ""
    }
}

/// Ce que Pico a compris, en pastilles.
struct ParsedPreview: View {
    @Environment(AppState.self) private var state
    let parsed: ParsedEntry
    let accent: Color

    var body: some View {
        FlowLayout(spacing: 6) {
            Text(parsed.title.isEmpty ? "…" : parsed.title)
                .font(Theme.ui(12.5, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.trailing, 4)
            if parsed.isSomeday { Chip(text: "Un jour", icon: "moon.stars.fill", color: Theme.lavender) }
            if let d = parsed.plannedDate {
                Chip(text: d.relativeLabel(today: state.today) + (parsed.plannedSlot == .evening ? " soir" : ""),
                     icon: parsed.plannedSlot == .evening ? "moon.fill" : "sun.max.fill", color: Theme.sun)
            }
            if let t = parsed.plannedTime { Chip(text: t.timeLabel, icon: "clock", color: Theme.sun) }
            if let due = parsed.dueDate { Chip(text: "Échéance " + due.relativeLabel(today: state.today), icon: "flag.fill", color: Theme.coral) }
            if let r = parsed.recurrence { Chip(text: r.label, icon: "repeat", color: Theme.pine) }
            if let name = parsed.projectName {
                if let id = parsed.projectId, let p = state.project(id) {
                    Chip(text: p.name, icon: "folder.fill", color: Theme.color(for: id))
                } else {
                    Chip(text: "Nouveau projet « \(name) »", icon: "folder.badge.plus", color: Theme.sea)
                }
            }
            ForEach(parsed.tagNames, id: \.self) { Chip(text: $0, icon: "tag.fill", color: Theme.lavender) }
            if parsed.priority >= 2 {
                Chip(text: parsed.priority == 3 ? "Urgent" : "Important", icon: "exclamationmark", color: Theme.danger)
            }
            if let m = parsed.durationMinutes { Chip(text: m.durationLabel, icon: "hourglass", color: Theme.inkSoft) }
        }
    }
}
