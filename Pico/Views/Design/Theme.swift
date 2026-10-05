import SwiftUI
import AppKit
import PicoCore

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32) { self.init(nsColor: NSColor(hex: hex)) }

    /// Couleur qui suit l'apparence claire / sombre.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }
}

/// Direction "Calanque" : papier chaud, encre profonde, une couleur par liste.
enum Theme {
    static let paper = Color(light: 0xF7F3EC, dark: 0x14161B)
    static let sidebar = Color(light: 0xEEE7DB, dark: 0x1A1D23)
    static let card = Color(light: 0xFFFDF9, dark: 0x21252D)
    static let ink = Color(light: 0x1E2227, dark: 0xEDE9E2)
    static let inkSoft = Color(light: 0x6A6E75, dark: 0x9CA2AA)
    static let inkFaint = Color(light: 0xAFB2B7, dark: 0x5B616A)
    static let line = Color(light: 0xE3DACB, dark: 0x2D313A)

    static let sea = Color(hex: 0x2F6FEB)
    static let sun = Color(hex: 0xF0A020)
    static let coral = Color(hex: 0xEC6A5C)
    static let pine = Color(hex: 0x2E9D6E)
    static let lavender = Color(hex: 0x8B78E6)
    static let stone = Color(hex: 0x8A8F98)
    static let danger = Color(hex: 0xE5484D)

    static let projectPalette: [Color] = [
        Color(hex: 0x2F6FEB), Color(hex: 0xEC6A5C), Color(hex: 0x2E9D6E), Color(hex: 0x8B78E6),
        Color(hex: 0xF0A020), Color(hex: 0x1FA3B8), Color(hex: 0xD9548E), Color(hex: 0x7C8B3A),
    ]

    /// Couleur stable d'un projet, derivee de son identifiant.
    static func color(for id: EntityID) -> Color {
        // FNV-1a ; les bits bas se repartissent mal sur des UUID, on prend les bits hauts.
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in id.rawValue.utf8 { h ^= UInt64(byte); h = h &* 0x100_0000_01B3 }
        return projectPalette[Int((h >> 29) % UInt64(projectPalette.count))]
    }

    /// Titres : serif editorial (New York).
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension SidebarItem {
    var accent: Color {
        switch self {
        case .inbox: Theme.sea
        case .today: Theme.sun
        case .upcoming: Theme.coral
        case .anytime: Theme.pine
        case .someday: Theme.lavender
        case .logbook: Theme.stone
        case .project(let id): Theme.color(for: id)
        }
    }
}
