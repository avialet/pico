import SwiftUI
import VialetKit
import PicoCore

// Jauge et illustrations propres a Pico (le reste des composants vient de VialetKit).

/// Jauge de charge de la journee.
struct LoadGauge: View {
    let minutes: Int
    var capacity = 6 * 60
    let color: Color

    var body: some View {
        let ratio = min(1.2, Double(minutes) / Double(capacity))
        let over = minutes > capacity
        HStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(colors: over ? [color, Theme.danger] : [color.opacity(0.7), color],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * min(1, ratio))
                }
            }
            .frame(width: 160, height: 6)
            Text(minutes == 0 ? "Aucune durée estimée" : "\(minutes.durationLabel) prévues sur \(capacity.durationLabel)")
                .font(Theme.ui(12, weight: .medium))
                .foregroundStyle(over ? Theme.danger : Theme.inkSoft)
            if over {
                Text("Journée chargée").font(Theme.ui(11, weight: .bold)).foregroundStyle(Theme.danger)
            }
        }
        .animation(.snappy, value: minutes)
    }
}

/// Vague (illustrations).
struct WaveLine: Shape {
    var cycles: CGFloat = 2

    func path(in r: CGRect) -> Path {
        var p = Path()
        let steps = 80
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let point = CGPoint(x: r.minX + r.width * t, y: r.midY + sin(t * .pi * 2 * cycles) * r.height / 2)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        return p
    }
}

/// Soleil sur la mer : etat vide des listes.
struct HorizonIllustration: View {
    let accent: Color
    @State private var drift = false

    var body: some View {
        VStack(spacing: 7) {
            Circle()
                .fill(LinearGradient(colors: [accent, accent.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                .frame(width: 74, height: 74)
                .frame(height: 40, alignment: .top)
                .clipped()
                .offset(y: drift ? -2 : 2)
            ForEach(0..<3) { i in
                WaveLine(cycles: 2.5)
                    .stroke(accent.opacity(0.55 - Double(i) * 0.15),
                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .frame(width: 130 - CGFloat(i) * 26, height: 7)
                    .offset(x: drift ? CGFloat(i % 2 == 0 ? 4 : -4) : CGFloat(i % 2 == 0 ? -4 : 4))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}
