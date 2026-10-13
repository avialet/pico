import AppKit
import VialetKit
import PicoCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // Mode capture : ni raccourci global, ni reseau.
        if runSnapshotIfRequested() { return }
        #endif
        WindowSummoner.onFocus = { AppState.shared.focusQuickAdd() }
        HotKeyController.shared.start { QuickEntry.shared.toggle() }
        // Laisse l'app s'afficher avant le moindre appel reseau.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            MainActor.assumeIsolated { Updater.shared.checkAutomatically() }
        }
    }

    /// Liens `pico://` : `pico://new` ouvre la fenetre de saisie d'une tache,
    /// `pico://new?title=...` la preremplit (rien n'est cree sans validation).
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "pico" {
            switch url.host {
            case "new":
                let title = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first { $0.name == "title" }?.value ?? ""
                QuickEntry.shared.show(prefill: String(title.prefix(300)))
            default: WindowSummoner.show()
            }
        }
    }

    /// Pico reste disponible (raccourci global, barre des menus) fenetre fermee.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { WindowSummoner.show() }
        return true
    }
}

#if DEBUG
/// Mode capture sans ecran (voir SnapshotRunner) : `Pico -PicoSnapshot <dossier> [-PicoSnapshotSeed 1]
/// [-PicoSnapshotAppearance dark] [-PicoSnapshotOnly a,b] [-PicoSnapshotSize 1220x780]`, avec PICO_DB_PATH
/// vers une base jetable. Ecrit `mainWindow` (Aujourd'hui), `settings`, `about`, `aVenir`, `projet`,
/// `detail` (tache ouverte dans le panneau de detail) et `floatingPanel` (saisie rapide preremplie),
/// `-sombre` en sombre, dans le dossier, puis quitte.
extension AppDelegate {
    func runSnapshotIfRequested() -> Bool {
        guard SnapshotRequest.parse(prefix: Brand.name, arguments: CommandLine.arguments) != nil else { return false }
        let state = AppState.shared
        state.snapshotLayout = true
        if UserDefaults.standard.bool(forKey: Brand.key("SnapshotSeed")) {
            try? DemoData.seed(state.db)
            state.reload()
        }
        let main: @MainActor () -> NSWindow? = { WindowSummoner.mainWindow }
        let standard = SnapshotRunner.standardScenarios(mainWindow: main, identity: Brand.identity)
            .filter { $0.name != "floatingPanel" }
        let pico = [
            SnapshotScenario("aVenir") {
                try await Self.show(.upcoming)
                return main()
            },
            SnapshotScenario("projet") {
                guard let project = state.activeProjects.first(where: { $0.name == "Migration serveurs" }) else { return nil }
                try await Self.show(.project(project.id))
                return main()
            },
            SnapshotScenario("detail") {
                try await Self.show(.today, selecting: "Pr\u{00E9}parer la d\u{00E9}mo de la recette")
                return main()
            },
            SnapshotScenario("floatingPanel") {
                QuickEntry.shared.show(prefill: "Appeler le comptable vendredi 10h @appel ~20m")
                try await Task.sleep(for: .seconds(1))
                return NSApp.windows.first { $0 is FloatingPanel && $0.isVisible }
            },
        ]
        return SnapshotRunner.runIfRequested(prefix: Brand.name, scenarios: standard + pico)
    }

    /// Affiche une liste, et ouvre une de ses taches dans le panneau de detail.
    private static func show(_ item: SidebarItem, selecting title: String? = nil) async throws {
        let state = AppState.shared
        state.selection = item
        try await Task.sleep(for: .milliseconds(600))
        if let title, let todo = state.sections.flatMap(\.todos).first(where: { $0.title == title }) {
            state.selectedTodoIds = [todo.id]
            state.showInspector = true
        }
        try await Task.sleep(for: .seconds(1))
    }
}
#endif
