import SwiftUI
import ServiceManagement
import PicoCore

struct SettingsView: View {
    @State private var hotKey = HotKeyController.shared
    @AppStorage("PicoMenuBar") private var menuBarVisible = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    @State private var appearance = AppearanceChoice.current

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Réglages").font(Theme.display(26)).foregroundStyle(Theme.ink)
                Text(".").font(Theme.display(26)).foregroundStyle(Theme.sun)
            }

            card(icon: "keyboard", color: Theme.sea, title: "Raccourci global") {
                HStack(spacing: 12) {
                    ShortcutRecorder()
                    Button("Rétablir") { hotKey.shortcut = .default }
                        .buttonStyle(.plain)
                        .font(Theme.ui(12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .opacity(hotKey.shortcut == .default ? 0 : 1)
                }
                Text(hotKey.isTaken
                     ? "Cette combinaison est déjà utilisée par une autre app. Choisissez-en une autre."
                     : "Depuis n'importe quelle app : ouvre une petite fenêtre pour noter une tâche, sans quitter ce que vous faites.")
                    .font(Theme.ui(12))
                    .foregroundStyle(hotKey.isTaken ? Theme.danger : Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            card(icon: "power", color: Theme.pine, title: "Toujours là") {
                Toggle("Ouvrir Pico à la connexion", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                if loginNeedsApproval {
                    HStack(spacing: 6) {
                        Text("À autoriser dans Réglages Système › Ouverture.")
                            .font(Theme.ui(12)).foregroundStyle(Theme.coral)
                        Button("Ouvrir") { SMAppService.openSystemSettingsLoginItems() }
                            .buttonStyle(.link).font(Theme.ui(12, weight: .semibold))
                    }
                }
                Toggle("Icône dans la barre des menus", isOn: $menuBarVisible)
                Text("Fermer la fenêtre ne quitte pas Pico : le raccourci reste actif. ⌘Q pour quitter.")
                    .font(Theme.ui(12)).foregroundStyle(Theme.inkSoft)
            }

            card(icon: "arrow.down.circle", color: Theme.coral, title: "Mises à jour") {
                UpdateCard()
            }

            card(icon: "circle.lefthalf.filled", color: Theme.lavender, title: "Apparence") {
                Picker("", selection: $appearance) {
                    ForEach(AppearanceChoice.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: appearance) { _, choice in choice.apply() }
            }
        }
        .toggleStyle(.switch)
        .font(Theme.ui(13))
        .padding(26)
        .frame(width: 460)
        .background(Theme.paper)
        .fontDesign(.rounded)
    }

    private func card<Content: View>(icon: String, color: Color, title: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color.gradient))
                Text(title).font(Theme.ui(13.5, weight: .bold)).foregroundStyle(Theme.ink)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Pico login item: \(error)")
        }
        let status = SMAppService.mainApp.status
        loginNeedsApproval = status == .requiresApproval
        launchAtLogin = status == .enabled || status == .requiresApproval
    }
}

/// Bouton qui capture la prochaine combinaison de touches.
struct ShortcutRecorder: View {
    @State private var controller = HotKeyController.shared
    @State private var recording = false
    @State private var monitor: Any?
    @State private var invalid = false

    var body: some View {
        Button { recording ? stop() : start() } label: {
            HStack(spacing: 8) {
                Image(systemName: recording ? "record.circle" : "command")
                    .font(.system(size: 11, weight: .bold))
                    .symbolEffect(.pulse, isActive: recording)
                Text(recording ? (invalid ? "Ajoutez ⌘, ⌥ ou ⌃…" : "Tapez le raccourci…") : controller.shortcut.display)
                    .font(Theme.ui(14, weight: .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(recording ? .white : Theme.ink)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .frame(minWidth: 170)
            .background(Capsule().fill(recording ? AnyShapeStyle(Theme.sea.gradient) : AnyShapeStyle(Theme.ink.opacity(0.06))))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onDisappear { stop() }
    }

    private func start() {
        controller.suspend()
        recording = true
        invalid = false
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let consumed = MainActor.assumeIsolated { handle(event) }
            return consumed ? nil : event
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard recording else { return false }
        if event.keyCode == 53 { stop(); return true } // Echap : annuler
        guard let shortcut = HotKeyShortcut(event: event) else {
            invalid = true
            NSSound.beep()
            return true
        }
        controller.shortcut = shortcut
        stop()
        return true
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { controller.apply() }
        recording = false
    }
}
