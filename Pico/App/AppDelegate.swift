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

    /// Pico reste disponible (raccourci global, barre des menus) fenetre fermee.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { MainActor.assumeIsolated { WindowSummoner.show() } }
        return true
    }
}
