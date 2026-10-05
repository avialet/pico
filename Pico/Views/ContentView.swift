import SwiftUI
import PicoCore

struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Pico")
                .font(.largeTitle.bold())
            Text("Noyau \(PicoCore.version)")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
