import Foundation

/// Identite de Pico, version minimale : lue par les scripts du depot vialetapps (plaque, sites, hub).
/// Pico n'est pas encore sur VialetKit (prevu en 0.2.0) : le reste de l'app ne l'utilise pas encore,
/// l'icone illustree (soleil, vagues, coche) reste celle de scripts/make-icon.swift jusque-la.
enum Brand {
    static let name = "Pico"
    static let displayName = "Pico"
    static let accent: UInt32 = 0xF0A020
    /// Teintes de l'affiche (sites, plaques, DMG), calculees par scripts/teintes.py : texte `deep` sur `background`.
    static let background: UInt32 = 0xF0A020
    static let deep: UInt32 = 0x5F3D09
    static let pale: UInt32 = 0xFFEFDC
    static let night: UInt32 = 0x271701
    static let nightInk: UInt32 = 0xF1D2AD
    /// Pictogramme de la plaque : sous-ensemble SVG absolu (M L H V C Q Z), boite 0-100, trait non rempli.
    static let glyph = "M 22 54 L 44 76 L 80 28"
    /// Le blanc sur le jaune n'atteint pas 3:1 : le trait de la plaque prend la teinte sombre.
    static let strokeDeep = true
}
