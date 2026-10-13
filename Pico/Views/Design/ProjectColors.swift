import SwiftUI
import VialetKit
import PicoCore

/// Couleurs propres a Pico : une par liste, une par projet (palette fixe du kit).
extension Theme {
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

    /// Titres des listes, des jours et des taches.
    @MainActor static func listTitle(_ size: CGFloat) -> Font { display(size) }
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
