import VialetKit

/// Icone de barre des menus : masquee quand l'app Vialet est installee (reglage Automatique, Toujours, Jamais).
extension MenuBarPresence {
    static let shared = MenuBarPresence(app: Brand.identity)
}

/// Actions rapides (`pico://new`, `pico://today`), proposees par l'app Vialet dans son menu.
extension AppActions {
    static let shared: AppActions = {
        let actions = AppActions(Brand.identity, open: { WindowSummoner.show() },
                                 checkForUpdates: { WindowSummoner.show(); Updater.shared.check() })
        actions.register(AppAction("new", title: "Nouvelle tâche", symbol: "plus")) {
            QuickEntry.shared.show()
        }
        actions.register(AppAction("today", title: "Aujourd'hui", symbol: "sun.max")) {
            AppState.shared.selection = .today
            WindowSummoner.show()
        }
        return actions
    }()
}
