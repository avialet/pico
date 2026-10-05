import SwiftUI
import PicoCore

@main
struct PicoApp: App {
    @State private var state = AppState.shared

    var body: some Scene {
        WindowGroup("Pico") {
            MainWindow()
                .environment(state)
                .frame(minWidth: 820, minHeight: 520)
        }
        .defaultSize(width: 1_100, height: 700)
        .commands { PicoCommands(state: state) }
    }
}

struct PicoCommands: Commands {
    let state: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nouvelle tache") { state.newTodo() }.keyboardShortcut("n")
            Button("Nouveau projet") { state.newProject() }.keyboardShortcut("n", modifiers: [.command, .shift])
            Button("Nouvelle zone") { state.newArea() }.keyboardShortcut("n", modifiers: [.command, .option])
        }
        CommandMenu("Tache") {
            Button("Terminer / rouvrir") { state.toggleComplete() }.keyboardShortcut(".")
            Divider()
            Button("Aujourd'hui") { state.plan(state.today) }.keyboardShortcut("t")
            Button("Ce soir") { state.plan(state.today, slot: .evening) }.keyboardShortcut("e")
            Button("Demain") { state.plan(state.today.adding(days: 1)) }.keyboardShortcut("t", modifiers: [.command, .shift])
            Button("A tout moment") { state.plan(nil) }.keyboardShortcut("r")
            Button("Un jour") { state.moveToSomeday() }.keyboardShortcut("s")
            Divider()
            Menu("Deplacer vers") {
                Button("Inbox") { state.move(toProject: nil) }
                ForEach(state.activeProjects) { p in
                    Button(p.name) { state.move(toProject: p.id) }
                }
            }
            Divider()
            Button("Supprimer") { state.deleteSelected() }.keyboardShortcut(.delete, modifiers: .command)
        }
        CommandMenu("Aller a") {
            Button("Inbox") { state.selection = .inbox }.keyboardShortcut("1")
            Button("Aujourd'hui") { state.selection = .today }.keyboardShortcut("2")
            Button("A venir") { state.selection = .upcoming }.keyboardShortcut("3")
            Button("A tout moment") { state.selection = .anytime }.keyboardShortcut("4")
            Button("Un jour") { state.selection = .someday }.keyboardShortcut("5")
            Button("Journal") { state.selection = .logbook }.keyboardShortcut("6")
        }
        CommandGroup(after: .sidebar) {
            Button("Inspecteur") { state.showInspector.toggle() }.keyboardShortcut("i", modifiers: [.command, .option])
        }
    }
}
