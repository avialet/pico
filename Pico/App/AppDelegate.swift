import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            HotKeyController.shared.start()
            // Laisse l'app s'afficher avant le moindre appel reseau.
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                MainActor.assumeIsolated { Updater.shared.checkAutomatically() }
            }
        }
    }

    /// Liens `pico://` : `pico://new` ouvre la fenetre de saisie d'une tache,
    /// `pico://new?title=...` la preremplit (rien n'est cree sans validation).
    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated {
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
    }

    /// Pico reste disponible (raccourci global, barre des menus) fenetre fermee.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { MainActor.assumeIsolated { WindowSummoner.show() } }
        return true
    }
}
