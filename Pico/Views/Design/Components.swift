import SwiftUI
import PicoCore

/// Case a cocher ronde, remplie avec un rebond.
struct CheckCircle: View {
    let checked: Bool
    let color: Color
    var size: CGFloat = 20
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(checked ? color : (hovering ? color : Theme.inkFaint), lineWidth: 1.6)
                    .background(Circle().fill(hovering && !checked ? color.opacity(0.12) : .clear))
                if checked {
                    Circle().fill(color.gradient)
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.48, weight: .heavy))
                        .foregroundStyle(.white)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .frame(width: size, height: size)
            .scaleEffect(checked ? 1.0 : (hovering ? 1.08 : 1))
            .animation(.spring(response: 0.32, dampingFraction: 0.55), value: checked)
            .animation(.easeOut(duration: 0.12), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Pastille d'information.
struct Chip: View {
    let text: String
    var icon: String?
    var color: Color = Theme.inkSoft
    var filled = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 9.5, weight: .bold)) }
            Text(text).font(Theme.ui(11.5, weight: .semibold)).lineLimit(1)
        }
        .padding(.horizontal, 8).padding(.vertical, 3.5)
        .foregroundStyle(filled ? Color.white : color)
        .background(Capsule().fill(filled ? AnyShapeStyle(color.gradient) : AnyShapeStyle(color.opacity(0.13))))
    }
}

/// Pastille cliquable (inspecteur).
struct ChipButton: View {
    let text: String
    var icon: String?
    var color: Color
    var selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).font(.system(size: 10.5, weight: .bold)) }
                Text(text).font(Theme.ui(12, weight: .semibold))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundStyle(selected ? Color.white : Theme.ink)
            .background(
                Capsule().fill(selected ? AnyShapeStyle(color.gradient)
                               : AnyShapeStyle(hovering ? color.opacity(0.16) : Theme.ink.opacity(0.05)))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: selected)
    }
}

/// Anneau d'avancement (projets).
struct ProgressRing: View {
    let fraction: Double
    let color: Color
    var size: CGFloat = 16
    var lineWidth: CGFloat = 2

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if fraction >= 1 {
                Image(systemName: "checkmark").font(.system(size: size * 0.45, weight: .heavy)).foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
        .animation(.snappy, value: fraction)
    }
}

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

/// Halo de couleur de la liste courante sur fond papier.
struct AmbientBackground: View {
    let accent: Color

    var body: some View {
        ZStack {
            Theme.paper
            RadialGradient(colors: [accent.opacity(0.22), accent.opacity(0)],
                           center: .topTrailing, startRadius: 0, endRadius: 620)
            RadialGradient(colors: [accent.opacity(0.07), .clear],
                           center: .bottomLeading, startRadius: 0, endRadius: 460)
        }
        .ignoresSafeArea()
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

/// Disposition en lignes qui passent a la ligne (pastilles).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
