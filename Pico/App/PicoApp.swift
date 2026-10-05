import SwiftUI
import PicoCore

@main
struct PicoApp: App {
    var body: some Scene {
        WindowGroup("Pico") {
            ContentView()
        }
        .defaultSize(width: 1_000, height: 680)
    }
}
