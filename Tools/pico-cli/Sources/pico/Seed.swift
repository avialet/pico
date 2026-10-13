import ArgumentParser
import Foundation
import PicoCore

struct Seed: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remplit une base de demonstration (refuse la base principale sans --force).")

    @Flag(help: "Autorise l'ecriture dans la base principale.")
    var force = false

    func run() throws {
        let isDefault = ProcessInfo.processInfo.environment["PICO_DB_PATH"] == nil
        if isDefault && !force {
            throw ValidationError("Definissez PICO_DB_PATH vers une base de demo, ou passez --force.")
        }
        try DemoData.seed(try AppDatabase.open())
        print("Base de demonstration remplie : \(AppDatabase.defaultURL.path)")
    }
}
