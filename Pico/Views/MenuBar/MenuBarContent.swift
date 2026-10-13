import SwiftUI
import PicoCore

/// Icone de la barre des menus ; garde aussi l'action d'ouverture de fenetre.
struct MenuBarLabel: View {
    @Environment(AppState.self) private var state
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sun.horizon.fill")
            if state.todayCount > 0 { Text("\(state.todayCount)") }
        }
        .onAppear { WindowSummoner.openMainWindow = { openWindow(id: "main") } }
    }
}

struct MenuBarContent: View {
    @Environment(AppState.self) private var state
    @State private var hotKey = HotKeyController.shared

    var body: some View {
        Button("Nouvelle tâche…   \(hotKey.shortcut.display)") { QuickEntry.shared.show() }
        Button("Ouvrir Pico") { WindowSummoner.show() }
        Divider()
        let today = (try? state.todos.today(state.today)) ?? []
        if today.isEmpty {
            Text("Rien de prévu aujourd'hui")
        } else {
            Text("Aujourd'hui")
            ForEach(today.prefix(8)) { todo in
                Toggle(todo.title, isOn: Binding(
                    get: { todo.status != .open },
                    set: { _ in state.toggleComplete([todo.id]) }))
            }
            if today.count > 8 { Text("… et \(today.count - 8) autres") }
        }
        Divider()
        SettingsLink { Text("Réglages…") }.keyboardShortcut(",")
        Button("Quitter Pico") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
