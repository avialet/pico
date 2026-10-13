import SwiftUI
import VialetKit

/// Identite de l'app : le seul fichier Swift qui connait son nom, ses teintes et son glyphe.
enum Brand {
    static let name = "Pico"
    static let displayName = "Pico"
    /// Teintes de l'affiche (sites, plaques, DMG, interface), calculees par scripts/teintes.py :
    /// texte `deep` sur `background`. Une teinte par ligne `cle: 0x...` (lue par les scripts du socle).
    static let palette = AccentPalette(accent: 0xF0A020, background: 0xF0A020,
                                       deep: 0x5F3D09, pale: 0xFFEFDC,
                                       night: 0x271701, nightInk: 0xF1D2AD)
    /// Pictogramme de la plaque (une coche) : sous-ensemble SVG absolu (M L H V C Q Z), boite 0-100,
    /// trait non rempli.
    static let glyph = "M 22 54 L 44 76 L 80 28"
    /// Trait du glyphe en `deep` plutot qu'en blanc : le blanc sur le jaune n'atteint pas 3:1.
    static let strokeDeep = true
    static let identity = AppIdentity(name: name, displayName: displayName, repository: "avialet/pico",
                                      bundleIdentifier: "fr.vialet.pico", palette: palette, glyph: glyph,
                                      strokeDeep: strokeDeep)
    static let updater = UpdaterConfiguration(identity)

    /// Cles UserDefaults, prefixees par le nom de l'app (`PicoHotKey`, `PicoMenuBar`, `PicoAppearance`,
    /// `PicoAutoUpdate`, `PicoLastUpdateCheck` : les memes qu'en 0.1, reglages conserves).
    static func key(_ suffix: String) -> String { identity.key(suffix) }
}

extension Updater {
    static let shared = Updater(configuration: Brand.updater)
}

extension HotKeyController {
    /// ⇧⌘Espace par defaut, comme en 0.1 (meme cle et meme JSON : le raccourci choisi est conserve).
    static let shared = HotKeyController(defaultsKey: Brand.key("HotKey"), logName: Brand.displayName,
                                         initial: .space([.command, .shift]))
}
