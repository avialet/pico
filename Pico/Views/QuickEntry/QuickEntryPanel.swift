import AppKit
import SwiftUI
import Observation
import VialetKit
import PicoCore

/// Fenetre flottante de saisie, ouverte par le raccourci global (FloatingPanelController du kit :
/// panneau non activant, Echap ou clic ailleurs le referment). Garde la phrase a preremplir.
@MainActor
@Observable
final class QuickEntry {
    static let shared = QuickEntry()
    /// Marge transparente autour de la carte : l'ombre de PanelCard (rayon 18, decalage 8) s'y estompe
    /// sans etre coupee par le bord de la fenetre.
    static let margin: CGFloat = 32
    /// Carte de 592 pt de large, et la marge tout autour.
    static let size = CGSize(width: 592 + 2 * margin, height: 176 + 2 * margin)

    /// Phrase a afficher a l'ouverture (ex. `pico://new?title=...`).
    private(set) var prefill = ""
    private let panel: FloatingPanelController<AnyView>

    private init() {
        panel = FloatingPanelController(size: Self.size) { AnyView(QuickEntryView().environment(AppState.shared)) }
    }

    /// Incremente a chaque ouverture, pour redonner le focus au champ.
    var openCount: Int { panel.openCount }
    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show(prefill: String = "") {
        self.prefill = prefill
        panel.show()
    }

    func hide() { panel.hide() }
}

struct QuickEntryView: View {
    @Environment(AppState.self) private var state
    private let entry: QuickEntry = .shared
    @State private var text = ""
    @State private var confirmation: String?
    @FocusState private var focused: Bool

    var body: some View {
        let parsed = state.parser.parse(text)
        VStack(spacing: 0) {
            card(parsed)
            Spacer(minLength: 0)
        }
        .padding(QuickEntry.margin)
        .onAppear { text = entry.prefill; focused = true }
        .onChange(of: entry.openCount) { _, _ in
            text = entry.prefill
            confirmation = nil
            focused = true
        }
        .onChange(of: text) { _, value in
            // Plusieurs lignes collees = une tache par ligne.
            guard value.contains(where: \.isNewline) else { return }
            let lines = value.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \t-*•☐[]")) }
                .filter { !$0.isEmpty }
            text = ""
            let created = lines.compactMap { state.capture(state.parser.parse($0)) }
            if !created.isEmpty { confirm(created.count == 1 ? state.destinationLabel(of: created[0]) : "\(created.count) tâches") }
        }
    }

    private func card(_ parsed: ParsedEntry) -> some View {
        PanelCard { fields(parsed) }
            .animation(.snappy(duration: 0.2), value: confirmation)
    }

    private func fields(_ parsed: ParsedEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [Theme.sun, Theme.coral], startPoint: .top, endPoint: .bottom))
                    Image(systemName: confirmation == nil ? "plus" : "checkmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 30, height: 30)

                if let confirmation {
                    Text("Ajouté · \(confirmation)")
                        .font(Theme.ui(19, weight: .semibold))
                        .foregroundStyle(Theme.pine)
                        .transition(.opacity)
                } else {
                    TextField("", text: $text, prompt: Text("Nouvelle tâche…").foregroundStyle(Theme.inkFaint))
                        .textFieldStyle(.plain)
                        .font(Theme.ui(20, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .focused($focused)
                        .onSubmit { submit(parsed) }
                }
                Spacer(minLength: 0)
                Wordmark.Mini(Brand.name)
            }

            Group {
                if text.isEmpty {
                    Text("demain 14h  ·  #projet  ·  @tag  ·  !!  ·  ~30m  ·  pour vendredi")
                        .font(Theme.ui(12, weight: .medium))
                        .foregroundStyle(Theme.inkFaint)
                } else {
                    ParsedPreview(parsed: parsed, accent: Theme.sun)
                }
            }
            .frame(minHeight: 22, alignment: .topLeading)
            .opacity(confirmation == nil ? 1 : 0)

            HStack(spacing: 14) {
                KeyHint("↩", "ajouter")
                KeyHint("esc", "fermer")
                Spacer()
                Text(destinationHint(parsed))
                    .font(Theme.ui(11.5, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .opacity(confirmation == nil ? 1 : 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private func destinationHint(_ parsed: ParsedEntry) -> String {
        if parsed.isSomeday { return "→ Un jour" }
        if let d = parsed.plannedDate { return "→ " + (d <= state.today ? "Aujourd'hui" : d.relativeLabel(today: state.today)) }
        if let name = parsed.projectName { return "→ " + (parsed.projectId.flatMap { state.project($0)?.name } ?? name) }
        return "→ Inbox"
    }

    private func submit(_ parsed: ParsedEntry) {
        guard let created = state.capture(parsed) else { NSSound.beep(); return }
        text = ""
        confirm(state.destinationLabel(of: created))
    }

    private func confirm(_ label: String) {
        confirmation = label
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            QuickEntry.shared.hide()
        }
    }
}
