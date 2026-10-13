import AppKit
import Carbon.HIToolbox
import Observation

/// Raccourci clavier global (code de touche independant de la disposition).
struct HotKeyShortcut: Codable, Equatable, Sendable {
    var keyCode: UInt16
    /// `NSEvent.ModifierFlags.rawValue`, limite a ⌘ ⌥ ⌃ ⇧.
    var modifiers: UInt
    /// Nom de la touche tel qu'affiche ("Espace", "P"...).
    var keyName: String

    /// ⇧⌘Espace : libre par defaut sur macOS (⌃Espace change de source de saisie,
    /// ⌘Espace ouvre Spotlight, ⌥Espace tape une espace insecable).
    static let `default` = HotKeyShortcut(
        keyCode: UInt16(kVK_Space),
        modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue,
        keyName: "Espace")

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }

    /// "⇧⌘Espace", dans l'ordre standard macOS ⌃⌥⇧⌘.
    var display: String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s + keyName
    }

    /// Construit un raccourci depuis une frappe ; nil sans ⌘, ⌥ ou ⌃.
    init?(event: NSEvent) {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !mods.intersection([.command, .option, .control]).isEmpty else { return nil }
        self.init(keyCode: event.keyCode, modifiers: mods.rawValue, keyName: Self.name(for: event))
    }

    init(keyCode: UInt16, modifiers: UInt, keyName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyName = keyName
    }

    private static func name(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space: return "Espace"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1...kVK_F12: break
        default: break
        }
        let chars = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespaces) ?? ""
        return chars.isEmpty ? "#\(event.keyCode)" : chars.uppercased()
    }
}

/// Enregistrement Carbon : seul moyen d'avoir un raccourci global sans
/// demander l'autorisation d'accessibilite.
@MainActor
final class GlobalHotKey {
    static let shared = GlobalHotKey()
    var action: (() -> Void)?
    private var ref: EventHotKeyRef?
    private var handlerInstalled = false

    /// Renvoie false si la combinaison est deja prise par une autre app.
    @discardableResult
    func register(_ shortcut: HotKeyShortcut) -> Bool {
        unregister()
        installHandler()
        let id = EventHotKeyID(signature: OSType(0x5049_434F), id: 1) // 'PICO'
        let status = RegisterEventHotKey(UInt32(shortcut.keyCode), shortcut.carbonModifiers, id,
                                         GetApplicationEventTarget(), 0, &ref)
        return status == noErr
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { GlobalHotKey.shared.action?() }
            }
            return noErr
        }, 1, &spec, nil, nil)
        handlerInstalled = true
    }
}

/// Raccourci choisi par l'utilisateur, persiste et enregistre.
@MainActor
@Observable
final class HotKeyController {
    static let shared = HotKeyController()
    private static let defaultsKey = "PicoHotKey"

    var shortcut: HotKeyShortcut {
        didSet {
            if let data = try? JSONEncoder().encode(shortcut) {
                UserDefaults.standard.set(data, forKey: Self.defaultsKey)
            }
            apply()
        }
    }
    private(set) var isTaken = false

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(HotKeyShortcut.self, from: data) {
            shortcut = saved
        } else {
            shortcut = .default
        }
    }

    func start() {
        GlobalHotKey.shared.action = { QuickEntry.shared.toggle() }
        apply()
    }

    /// Suspend le raccourci (pendant qu'on en enregistre un nouveau).
    func suspend() { GlobalHotKey.shared.unregister() }

    func apply() {
        isTaken = !GlobalHotKey.shared.register(shortcut)
        NSLog("Pico raccourci global \(shortcut.display) : \(isTaken ? "deja pris" : "actif")")
    }
}

/// Fait apparaitre / disparaitre Pico.
@MainActor
enum WindowSummoner {
    /// Ouvre la fenetre principale si elle a ete fermee (fourni par une vue SwiftUI).
    static var openMainWindow: (() -> Void)?

    static var mainWindow: NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue.hasPrefix("main") == true }
    }

    static func toggle() {
        if NSApp.isActive, let window = mainWindow, window.isKeyWindow, window.isVisible {
            NSApp.hide(nil)
        } else {
            show(focusCapture: true)
        }
    }

    static func show(focusCapture: Bool = false) {
        NSApp.unhide(nil)
        NSApp.activate()
        if let window = mainWindow, window.isVisible || window.isMiniaturized {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            openMainWindow?()
        }
        if focusCapture {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                MainActor.assumeIsolated { AppState.shared.focusQuickAdd() }
            }
        }
    }
}
