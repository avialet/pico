import Foundation
import PicoCore

let demoDataTests: (String, [Test]) = ("DemoData", [
    Test("seedFillsEveryList") {
        let (db, todos, projects, _) = try makeServices()
        try DemoData.seed(db, today: oct5)
        expectEqual(try projects.areas().map(\.name), ["Bureau", "Perso"])
        expectEqual(try projects.projects().count, 3)
        expectEqual(try todos.inbox().count, 2)
        expectEqual(try todos.someday().count, 2)
        let today = try todos.today(oct5).map(\.title)
        expect(today.contains("Relancer le fournisseur sur le ticket de migration"), "aujourd'hui")
        expect(!(try todos.upcoming(from: oct5)).isEmpty, "a venir")
    },
    Test("seedRefusesFilledBase") {
        let (db, _, _, _) = try makeServices()
        try DemoData.seed(db, today: oct5)
        expectThrows({ try DemoData.seed(db, today: oct5) }, "base deja remplie")
    },
])
