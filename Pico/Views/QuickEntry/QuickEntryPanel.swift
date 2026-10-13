import AppKit
import SwiftUI
import Observation
import PicoCore

/// Petite fenetre flottante de saisie, ouverte par le raccourci global.
/// Panneau "non activant" : on tape dedans sans que Pico passe au premier plan.
final class QuickEntryPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: QuickEntry.size.width, height: QuickEntry.size.height),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Clic ailleurs : on referme.
    override func resignKey() {
        super.resignKey()
        MainActor.assumeIsolated { QuickEntry.shared.hide() }
    }

    /// Echap.
    override func cancelOperation(_ sender: Any?) {
        MainActor.assumeIsolated { QuickEntry.shared.hide() }
    }
}

@MainActor
@Observable
final class QuickEntry {
    static let shared = QuickEntry()
    static let size = CGSize(width: 640, height: 190)

    /// Incremente a chaque ouverture, pour redonner le focus au champ.
    private(set) var openCount = 0
    var isVisible: Bool { panel?.isVisible == true }
    private var panel: QuickEntryPanel?

    func toggle() { isVisible ? hide() : show() }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        position(panel)
        openCount += 1
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        })
    }

    private func makePanel() -> QuickEntryPanel {
        let panel = QuickEntryPanel()
        let host = NSHostingView(rootView: QuickEntryView().environment(AppState.shared).fontDesign(.rounded))
        host.frame = NSRect(origin: .zero, size: Self.size)
        panel.contentView = host
        return panel
    }

    /// Centre horizontalement, au tiers haut de l'ecran ou se trouve la souris.
    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let origin = NSPoint(x: frame.midX - Self.size.width / 2,
                             y: frame.maxY - frame.height * 0.22 - Self.size.height)
        panel.setFrame(NSRect(origin: origin, size: Self.size), display: true)
    }
}

struct QuickEntryView: View {
    @Environment(AppState.self) private var state
    @State private var entry = QuickEntry.shared
    @State private var text = ""
    @State private var confirmation: String?
    @FocusState private var focused: Bool

    var body: some View {
        let parsed = state.parser.parse(text)
        VStack(spacing: 0) {
            card(parsed)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .onAppear { focused = true }
        .onChange(of: entry.openCount) { _, _ in
            text = ""
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
                Text("pico.")
                    .font(Theme.display(15, weight: .heavy))
                    .foregroundStyle(Theme.inkFaint)
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
                hint("↩", "ajouter")
                hint("⎋", "fermer")
                Spacer()
                Text(destinationHint(parsed))
                    .font(Theme.ui(11.5, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .opacity(confirmation == nil ? 1 : 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.card)
                .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        .animation(.snappy(duration: 0.2), value: confirmation)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(Theme.ui(11, weight: .bold))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.ink.opacity(0.07)))
            Text(label).font(Theme.ui(11.5))
        }
        .foregroundStyle(Theme.inkSoft)
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
