import SwiftUI
import AppKit
import VialetKit
import PicoCore

@main
struct PicoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState.shared
    @AppStorage(Brand.key("MenuBar")) private var menuBarVisible = true

    /// Teintes de l'app avant le premier rendu (et police Bricolage Grotesque des titres).
    init() { Theme.configure(Brand.palette) }

    var body: some Scene {
        Window(Brand.displayName, id: "main") {
            MainWindow()
                .environment(state)
                .fontDesign(.rounded)
                .frame(minWidth: 900, minHeight: 580)
                .onAppear { AppearanceChoice.current(defaultsKey: Brand.key("Appearance")).apply(defaultsKey: Brand.key("Appearance")) }
                .captureOpenWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 1_220, height: 780)
        .commands {
            AboutCommands(identity: Brand.identity)
            PicoCommands(state: state)
        }

        Settings {
            SettingsView()
        }

        MenuBarExtra(isInserted: $menuBarVisible) {
            MenuBarContent().environment(state)
        } label: {
            MenuBarLabel().environment(state)
        }
    }
}

struct PicoCommands: Commands {
    let state: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nouvelle tâche") { state.focusQuickAdd() }.keyboardShortcut("n")
            Button("Nouveau projet") { state.newProject() }.keyboardShortcut("n", modifiers: [.command, .shift])
            Button("Nouvelle zone") { state.newArea() }.keyboardShortcut("n", modifiers: [.command, .option])
        }
        CommandGroup(after: .textEditing) {
            Button("Rechercher") { state.focusSearch() }.keyboardShortcut("f")
        }
        CommandMenu("Tâche") {
            Button("Terminer / rouvrir") { state.toggleComplete() }.keyboardShortcut(".")
            Button("Renommer") { state.editingTodoId = state.selectedTodoIds.first }.keyboardShortcut(.return, modifiers: .command)
            Divider()
            Button("Aujourd'hui") { state.plan(state.today) }.keyboardShortcut("t")
            Button("Ce soir") { state.plan(state.today, slot: .evening) }.keyboardShortcut("e")
            Button("Demain") { state.plan(state.today.adding(days: 1)) }.keyboardShortcut("t", modifiers: [.command, .shift])
            Button("À tout moment") { state.plan(nil) }.keyboardShortcut("r")
            Button("Un jour") { state.moveToSomeday() }.keyboardShortcut("s")
            Divider()
            Menu("Déplacer vers") {
                Button("Inbox") { state.move(toProject: nil) }
                ForEach(state.activeProjects) { p in
                    Button(p.name) { state.move(toProject: p.id) }
                }
            }
            Divider()
            Button("Supprimer") { state.delete() }.keyboardShortcut(.delete, modifiers: .command)
        }
        CommandMenu("Aller à") {
            Button("Inbox") { state.selection = .inbox }.keyboardShortcut("1")
            Button("Aujourd'hui") { state.selection = .today }.keyboardShortcut("2")
            Button("À venir") { state.selection = .upcoming }.keyboardShortcut("3")
            Button("À tout moment") { state.selection = .anytime }.keyboardShortcut("4")
            Button("Un jour") { state.selection = .someday }.keyboardShortcut("5")
            Button("Journal") { state.selection = .logbook }.keyboardShortcut("6")
        }
        CommandGroup(after: .sidebar) {
            Button("Afficher le détail") { state.showInspector.toggle() }.keyboardShortcut("i", modifiers: [.command, .option])
            Menu("Apparence") {
                ForEach(AppearanceChoice.allCases, id: \.self) { choice in
                    Button(choice.label) { choice.apply(defaultsKey: Brand.key("Appearance")) }
                }
            }
        }
    }
}
