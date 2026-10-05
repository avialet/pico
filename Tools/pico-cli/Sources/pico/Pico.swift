import ArgumentParser
import PicoCore

@main
struct Pico: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pico",
        abstract: "Pico, gestionnaire de taches : porte d'entree en ligne de commande.",
        version: PicoCore.version,
        subcommands: [Version.self],
        defaultSubcommand: Version.self
    )
}

struct Version: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Affiche la version du noyau.")
    func run() throws {
        print("pico \(PicoCore.version)")
    }
}
