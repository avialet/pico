import Foundation

/// Donnees de demonstration, neutres : `pico seed` (CLI) et le mode capture de l'app
/// (`-PicoSnapshotSeed 1`). Chaines en echappements ASCII.
public enum DemoData {
    public struct NotEmpty: Error, CustomStringConvertible {
        public var description: String { "La base contient deja des donnees : graine refusee." }
    }

    /// Remplit une base vide : deux zones, trois projets, une vingtaine de taches autour de `today`.
    public static func seed(_ db: AppDatabase, today: DayDate = .today()) throws {
        let todos = TodoService(db: db), projects = ProjectService(db: db), tags = TagService(db: db)
        guard try projects.areas().isEmpty, try projects.projects(status: nil).isEmpty, try todos.inbox().isEmpty else {
            throw NotEmpty()
        }

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
        _ = try add("Pr\u{00E9}parer la d\u{00E9}mo de la recette", project: vitrine, planned: today, due: today.adding(days: 2),
                    minutes: 90, tags: [client], heading: h1, checklist: ["Jeu de donn\u{00E9}es", "Sc\u{00E9}nario", "Slides"])
        _ = try add("Valider les maquettes mobiles", project: vitrine, planned: today, minutes: 45)
        _ = try add("Point hebdo \u{00E9}quipe", planned: today, time: 14 * 60 + 30, minutes: 60, rule: "FREQ=WEEKLY;BYDAY=MO")
        _ = try add("Envoyer la facture d'octobre", planned: today.adding(days: -1), due: today, priority: 2)
        _ = try add("Lire l'article sur SwiftData", planned: today, slot: .evening, minutes: 20)
        _ = try add("Appeler le plombier", project: house, planned: today, slot: .evening, tags: [call])
        _ = try add("PROJ-142 Erreur 500 sur l'export CSV", project: infra, planned: today.adding(days: 1),
                    priority: 2, source: "jira", key: "PROJ-142")
        _ = try add("Revue de sprint", planned: today.adding(days: 3), time: 10 * 60, minutes: 60)
        _ = try add("Renouveler le certificat SSL", project: infra, planned: today.adding(days: 3), due: today.adding(days: 6))
        _ = try add("D\u{00E9}jeuner avec Sophie", planned: today.adding(days: 5), time: 12 * 60 + 30)
        _ = try add("Bilan trimestriel", planned: today.adding(days: 12), minutes: 120, tags: [client])
        _ = try add("Trier les factures du trimestre")
        _ = try add("Id\u{00E9}e : automatiser l'import des tickets Outlook")
        _ = try add("Mettre \u{00E0} jour la doc d'architecture", project: vitrine)
        _ = try add("Repeindre la chambre", project: house, someday: true)
        _ = try add("Apprendre le piano", someday: true)
        let done = try add("Commander les \u{00E9}crans", project: infra)
        try todos.complete(done.id, today: today)
    }
}
