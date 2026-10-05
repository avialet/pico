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
        let db = try AppDatabase.open()
        let todos = TodoService(db: db), projects = ProjectService(db: db), tags = TagService(db: db)
        let today = DayDate.today()

        let work = try projects.createArea("Bureau", icon: "briefcase")
        let home = try projects.createArea("Perso", icon: "house")
        let infra = try projects.createProject("Migration serveurs", areaId: work.id, notes: "Migration des serveurs avant fin octobre.")
        let vitrine = try projects.createProject("Refonte site vitrine", areaId: work.id)
        let house = try projects.createProject("Appartement", areaId: home.id)
        let h1 = try projects.createHeading("Recette", in: vitrine.id)

        let urgent = try tags.findOrCreate("urgent")
        let call = try tags.findOrCreate("appel")
        let client = try tags.findOrCreate("client")

        func add(_ title: String, project: Project? = nil, planned: DayDate? = nil, slot: PlannedSlot = .day,
                 time: Int? = nil, due: DayDate? = nil, minutes: Int? = nil, priority: Int = 0,
                 tags tagList: [Tag] = [], rule: String? = nil, someday: Bool = false, heading: Heading? = nil,
                 notes: String = "", checklist: [String] = [], source: String? = nil, key: String? = nil) throws -> Todo {
            var t = Todo(projectId: project?.id, headingId: heading?.id, title: title, notes: notes, priority: priority,
                         plannedDate: planned, plannedSlot: slot, plannedTime: time, dueDate: due,
                         durationMinutes: minutes, recurrenceRule: rule, source: source, externalKey: key,
                         externalURL: key.map { "https://jira.example.com/browse/\($0)" }, isSomeday: someday)
            t = try todos.create(t)
            if !tagList.isEmpty { try todos.setTags(tagList.map(\.id), on: t.id) }
            for c in checklist { try todos.addChecklistItem(c, to: t.id) }
            return t
        }

        _ = try add("Relancer le fournisseur sur le ticket de migration", project: infra, planned: today, time: 10 * 60,
                    minutes: 30, priority: 3, tags: [urgent, call], notes: "Demander la date de bascule DNS.")
        _ = try add("Préparer la démo de la recette", project: vitrine, planned: today, due: today.adding(days: 2),
                    minutes: 90, tags: [client], heading: h1, checklist: ["Jeu de données", "Scénario", "Slides"])
        _ = try add("Valider les maquettes mobiles", project: vitrine, planned: today, minutes: 45)
        _ = try add("Point hebdo équipe", planned: today, time: 14 * 60 + 30, minutes: 60, rule: "FREQ=WEEKLY;BYDAY=MO")
        _ = try add("Envoyer la facture d'octobre", planned: today.adding(days: -1), due: today, priority: 2)
        _ = try add("Lire l'article sur SwiftData", planned: today, slot: .evening, minutes: 20)
        _ = try add("Appeler le plombier", project: house, planned: today, slot: .evening, tags: [call])
        _ = try add("PROJ-142 Erreur 500 sur l'export CSV", project: infra, planned: today.adding(days: 1),
                    priority: 2, source: "jira", key: "PROJ-142")
        _ = try add("Revue de sprint", planned: today.adding(days: 3), time: 10 * 60, minutes: 60)
        _ = try add("Renouveler le certificat SSL", project: infra, planned: today.adding(days: 3), due: today.adding(days: 6))
        _ = try add("Déjeuner avec Sophie", planned: today.adding(days: 5), time: 12 * 60 + 30)
        _ = try add("Bilan trimestriel", planned: today.adding(days: 12), minutes: 120, tags: [client])
        _ = try add("Trier les factures du trimestre")
        _ = try add("Idée : automatiser l'import des tickets Outlook")
        _ = try add("Mettre à jour la doc d'architecture", project: vitrine)
        _ = try add("Repeindre la chambre", project: house, someday: true)
        _ = try add("Apprendre le piano", someday: true)
        let done = try add("Commander les écrans", project: infra)
        try todos.complete(done.id)
        print("Base de demonstration remplie : \(AppDatabase.defaultURL.path)")
    }
}
