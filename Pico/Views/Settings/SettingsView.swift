import SwiftUI
import VialetKit

/// Reglages : les quatre cartes standard du kit (raccourci, toujours la, mises a jour, apparence).
struct SettingsView: View {
    var body: some View {
        SettingsScreen(app: Brand.identity, hotKey: HotKeyController.shared, updater: Updater.shared,
                       menuBar: MenuBarPresence.shared,
                       hotKeyHint: "Depuis n'importe quelle app : ouvre une petite fenêtre pour noter une tâche, sans quitter ce que vous faites.")
    }
}
