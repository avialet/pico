import Foundation

/// Resultat de l'analyse d'une ligne de saisie rapide.
public struct ParsedEntry: Equatable, Sendable {
    public enum Kind: String, Sendable { case date, time, due, recurrence, project, tag, priority, duration, someday, evening }
    public struct Highlight: Equatable, Sendable {
        public let range: Range<String.Index>
        public let kind: Kind
    }

    public var title: String = ""
    public var plannedDate: DayDate?
    public var plannedSlot: PlannedSlot = .day
    public var plannedTime: Int?
    public var dueDate: DayDate?
    public var isSomeday = false
    public var priority = 0
    public var durationMinutes: Int?
    public var recurrence: RecurrenceRule?
    /// Texte tape apres `#`, meme sans projet correspondant.
    public var projectName: String?
    public var projectId: EntityID?
    public var tagNames: [String] = []
    public var highlights: [Highlight] = []

    public init() {}

    /// Construit la tache correspondante.
    public func makeTodo(now: Date = Date()) -> Todo {
        var todo = Todo(projectId: projectId, title: title, priority: priority, plannedDate: plannedDate,
                        plannedSlot: plannedSlot, plannedTime: plannedTime, dueDate: dueDate,
                        durationMinutes: durationMinutes, isSomeday: isSomeday, now: now)
        todo.recurrence = recurrence
        if isSomeday || plannedDate != nil || projectId != nil { todo.isInbox = false }
        return todo
    }
}

/// Analyse une ligne comme « Relancer le fournisseur demain 14h #Infra @urgent !! ~30m tous les lundis ».
/// Francais et anglais acceptes simultanement.
public struct QuickEntryParser: Sendable {
    public var today: DayDate
    /// Projets connus (id, nom) pour resoudre `#nom`.
    public var projects: [(id: EntityID, name: String)]

    public init(today: DayDate = .today(), projects: [(id: EntityID, name: String)] = []) {
        self.today = today
        self.projects = projects
    }

    // MARK: Vocabulaire

    static let weekdays: [String: Int] = [
        "dimanche": 1, "sunday": 1, "lundi": 2, "monday": 2, "mardi": 3, "tuesday": 3,
        "mercredi": 4, "wednesday": 4, "jeudi": 5, "thursday": 5, "vendredi": 6, "friday": 6,
        "samedi": 7, "saturday": 7,
    ]
    static let weekdayPattern = "(dimanche|sunday|lundi|monday|mardi|tuesday|mercredi|wednesday|jeudi|thursday|vendredi|friday|samedi|saturday)s?"

    static let months: [String: Int] = [
        "janvier": 1, "janv": 1, "jan": 1, "january": 1,
        "fevrier": 2, "février": 2, "fev": 2, "fév": 2, "feb": 2, "february": 2,
        "mars": 3, "march": 3, "mar": 3,
        "avril": 4, "avr": 4, "apr": 4, "april": 4,
        "mai": 5, "may": 5,
        "juin": 6, "jun": 6, "june": 6,
        "juillet": 7, "juil": 7, "jul": 7, "july": 7,
        "aout": 8, "août": 8, "aug": 8, "august": 8,
        "septembre": 9, "sept": 9, "sep": 9, "september": 9,
        "octobre": 10, "oct": 10, "october": 10,
        "novembre": 11, "nov": 11, "november": 11,
        "decembre": 12, "décembre": 12, "dec": 12, "déc": 12, "december": 12,
    ]
    static let monthPattern = "(janvier|janv|jan|january|fevrier|février|fev|fév|feb|february|mars|march|mar|avril|avr|apr|april|mai|may|juin|jun|june|juillet|juil|jul|july|aout|août|aug|august|septembre|sept|sep|september|octobre|oct|october|novembre|nov|november|decembre|décembre|dec|déc|december)\\.?"

    static let duePrefix = "(?:(?:échéance|echeance|deadline|due|avant le|avant|pour le|pour|by|d'ici le|d'ici)\\s+)"

    // MARK: Analyse

    public func parse(_ input: String) -> ParsedEntry {
        var entry = ParsedEntry()
        let text = input as NSString
        var consumed = [Bool](repeating: false, count: text.length)
        var highlights: [(NSRange, ParsedEntry.Kind)] = []

        func claim(_ range: NSRange, _ kind: ParsedEntry.Kind) {
            for i in range.location..<(range.location + range.length) { consumed[i] = true }
            highlights.append((range, kind))
        }
        func free(_ range: NSRange) -> Bool {
            guard range.location != NSNotFound else { return false }
            return !(range.location..<(range.location + range.length)).contains { consumed[$0] }
        }
        func matches(_ pattern: String) -> [NSTextCheckingResult] {
            let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            return regex.matches(in: input, range: NSRange(location: 0, length: text.length)).filter { free($0.range) }
        }
        func group(_ m: NSTextCheckingResult, _ i: Int) -> String? {
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : text.substring(with: r)
        }

        // 1. Recurrence (avant les jours de semaine, pour consommer « tous les lundis »).
        for m in matches("\\b(?:apr[eè]s ach[eè]vement|after completion)\\b") {
            entry.recurrence = entry.recurrence ?? RecurrenceRule(frequency: .daily)
            entry.recurrence?.basis = .completion
            claim(m.range, .recurrence)
        }
        for m in matches("\\b(?:chaque|tous les|toutes les|every)\\s+(?:(\\d+)\\s+)?(jours?|days?|semaines?|weeks?|mois|months?|ans?|ann[eé]es?|years?)\\b") {
            let interval = Int(group(m, 1) ?? "1") ?? 1
            let unit = (group(m, 2) ?? "").lowercased()
            let freq: RecurrenceRule.Frequency = unit.hasPrefix("j") || unit.hasPrefix("d") ? .daily
                : unit.hasPrefix("s") || unit.hasPrefix("w") ? .weekly
                : unit.hasPrefix("mo") ? .monthly : .yearly
            setRecurrence(&entry, RecurrenceRule(frequency: freq, interval: interval))
            claim(m.range, .recurrence)
        }
        for m in matches("\\b(?:chaque|tous les|every)\\s+\(Self.weekdayPattern)\\b") {
            let day = Self.weekdays[(group(m, 1) ?? "").lowercased()] ?? 2
            var rule = entry.recurrence ?? RecurrenceRule(frequency: .weekly)
            rule.frequency = .weekly
            rule.weekdays.insert(day)
            entry.recurrence = rule
            claim(m.range, .recurrence)
        }
        for m in matches("\\b(?:jours ouvr[eé]s|weekdays|en semaine)\\b") {
            setRecurrence(&entry, RecurrenceRule(frequency: .weekly, weekdays: [2, 3, 4, 5, 6]))
            claim(m.range, .recurrence)
        }
        for m in matches("\\b(daily|quotidien(?:ne)?|weekly|hebdo(?:madaire)?|monthly|mensuel(?:le)?|yearly|annuel(?:le)?)\\b") {
            let w = (group(m, 1) ?? "").lowercased()
            let freq: RecurrenceRule.Frequency = w.hasPrefix("d") || w.hasPrefix("q") ? .daily
                : w.hasPrefix("w") || w.hasPrefix("h") ? .weekly
                : w.hasPrefix("mo") || w.hasPrefix("me") ? .monthly : .yearly
            setRecurrence(&entry, RecurrenceRule(frequency: freq))
            claim(m.range, .recurrence)
        }

        // 2. Dates. Chaque motif renvoie la date ; le prefixe d'echeance la route vers dueDate.
        func assign(_ date: DayDate, isDue: Bool) {
            if isDue { entry.dueDate = date } else if entry.plannedDate == nil { entry.plannedDate = date }
        }
        func datePatterns() -> [(String, (NSTextCheckingResult, Int) -> DayDate?)] {
            [
                ("(?:aujourd'hui|aujourd’hui|today)", { _, _ in today }),
                ("(?:apr[eè]s[- ]demain|day after tomorrow)", { _, _ in today.adding(days: 2) }),
                ("(?:demain|tomorrow|tmr)", { _, _ in today.adding(days: 1) }),
                ("(?:ce week-?end|this weekend|week-?end)", { _, _ in nextWeekday(7, from: today, allowToday: true) }),
                ("(?:dans|in)\\s+(\\d+)\\s+(jours?|days?|semaines?|weeks?|mois|months?)", { m, g in
                    let n = Int(group(m, g) ?? "1") ?? 1
                    let unit = (group(m, g + 1) ?? "").lowercased()
                    if unit.hasPrefix("j") || unit.hasPrefix("d") { return today.adding(days: n) }
                    if unit.hasPrefix("s") || unit.hasPrefix("w") { return today.adding(days: 7 * n) }
                    return today.adding(months: n)
                }),
                ("(?:(?:lundi|monday|mardi|tuesday|mercredi|wednesday|jeudi|thursday|vendredi|friday|samedi|saturday|dimanche|sunday)\\s+prochain|next\\s+\(Self.weekdayPattern))", { m, g in
                    let word = text.substring(with: m.range).lowercased()
                    let name = Self.weekdays.keys.first { word.contains($0) } ?? "lundi"
                    return nextWeekday(Self.weekdays[name]!, from: today.startOfWeek.adding(days: 6), allowToday: false)
                }),
                ("(?:le\\s+|ce\\s+|on\\s+|this\\s+)?\(Self.weekdayPattern)", { m, g in
                    let name = (group(m, g) ?? "").lowercased()
                    return nextWeekday(Self.weekdays[name]!, from: today, allowToday: true)
                }),
                ("(\\d{4})-(\\d{2})-(\\d{2})", { m, g in
                    DayDate(year: Int(group(m, g)!)!, month: Int(group(m, g + 1)!)!, day: Int(group(m, g + 2)!)!)
                }),
                ("(\\d{1,2})/(\\d{1,2})(?:/(\\d{2,4}))?", { m, g in
                    let d = Int(group(m, g)!)!, mo = Int(group(m, g + 1)!)!
                    guard (1...31).contains(d), (1...12).contains(mo) else { return nil }
                    if let y = group(m, g + 2).flatMap({ Int($0) }) { return DayDate(year: y < 100 ? 2000 + y : y, month: mo, day: d) }
                    return nextOccurrence(month: mo, day: d)
                }),
                ("(?:le\\s+)?(\\d{1,2})(?:er)?\\s+\(Self.monthPattern)(?:\\s+(\\d{4}))?", { m, g in
                    let d = Int(group(m, g)!)!, mo = Self.months[(group(m, g + 1) ?? "").lowercased()] ?? 1
                    if let y = group(m, g + 2).flatMap({ Int($0) }) { return DayDate(year: y, month: mo, day: d) }
                    return nextOccurrence(month: mo, day: d)
                }),
                ("\(Self.monthPattern)\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(\\d{4}))?", { m, g in
                    let mo = Self.months[(group(m, g) ?? "").lowercased()] ?? 1, d = Int(group(m, g + 1)!)!
                    if let y = group(m, g + 2).flatMap({ Int($0) }) { return DayDate(year: y, month: mo, day: d) }
                    return nextOccurrence(month: mo, day: d)
                }),
            ]
        }
        for (pattern, resolve) in datePatterns() {
            // Groupe 1 = prefixe d'echeance eventuel ; les groupes du motif commencent a 2.
            for m in matches("\\b(\(Self.duePrefix))?\(pattern)\\b") {
                guard let date = resolve(m, 2) else { continue }
                let isDue = m.range(at: 1).location != NSNotFound
                assign(date, isDue: isDue)
                claim(m.range, isDue ? .due : .date)
            }
        }

        // 3. Heure.
        for m in matches("\\b(?:(?:à|a|at)\\s+)?(?<!~)(\\d{1,2})(?:h|:)(\\d{2})?\\s*(am|pm)?\\b|\\b(?:(?:à|a|at)\\s+)?(?<!~)(\\d{1,2})\\s*(am|pm)\\b") {
            var hour: Int, minute = 0
            if let h = group(m, 1) {
                hour = Int(h)!; minute = Int(group(m, 2) ?? "0") ?? 0
                if let ap = group(m, 3)?.lowercased() { if ap == "pm", hour < 12 { hour += 12 }; if ap == "am", hour == 12 { hour = 0 } }
            } else {
                hour = Int(group(m, 4)!)!
                let ap = group(m, 5)!.lowercased()
                if ap == "pm", hour < 12 { hour += 12 }; if ap == "am", hour == 12 { hour = 0 }
            }
            guard (0...23).contains(hour), (0...59).contains(minute) else { continue }
            entry.plannedTime = hour * 60 + minute
            claim(m.range, .time)
        }
        if entry.plannedTime != nil, entry.plannedDate == nil { entry.plannedDate = today }

        // 4. Soir, un jour.
        for m in matches("\\b(?:ce soir|tonight|this evening|evening|soir)\\b") {
            entry.plannedSlot = .evening
            if entry.plannedDate == nil { entry.plannedDate = today }
            claim(m.range, .evening)
        }
        for m in matches("\\b(?:un jour|someday)\\b") {
            entry.isSomeday = true
            claim(m.range, .someday)
        }

        // 5. Projet (#nom ou #"nom avec espaces"), tags, priorite, duree.
        for m in matches("(?:^|\\s)#(?:\"([^\"]+)\"|([^\\s#@]+))") {
            let name = group(m, 1) ?? group(m, 2) ?? ""
            entry.projectName = name
            entry.projectId = resolveProject(name)
            claim(m.range, .project)
        }
        for m in matches("(?:^|\\s)@([^\\s#@]+)") {
            entry.tagNames.append(group(m, 1) ?? "")
            claim(m.range, .tag)
        }
        for m in matches("(?:^|\\s)(!{1,3})(?=\\s|$)") {
            entry.priority = (group(m, 1)?.count ?? 1) >= 2 ? 3 : 2
            claim(m.range, .priority)
        }
        for m in matches("(?:^|\\s)~(?:(\\d+)h(\\d{2})?|(\\d+)\\s*(?:m|min|mn))\\b") {
            if let h = group(m, 1) { entry.durationMinutes = (Int(h) ?? 0) * 60 + (Int(group(m, 2) ?? "0") ?? 0) }
            else { entry.durationMinutes = Int(group(m, 3) ?? "0") }
            claim(m.range, .duration)
        }

        // 6. Titre = reste, espaces normalises.
        var title = ""
        for i in 0..<text.length where !consumed[i] {
            title.append(Character(UnicodeScalar(text.character(at: i)) ?? " "))
        }
        title = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: " ,;-–"))
        entry.title = title

        entry.highlights = highlights.sorted { $0.0.location < $1.0.location }.compactMap { r, kind in
            Range(r, in: input).map { ParsedEntry.Highlight(range: $0, kind: kind) }
        }
        return entry
    }

    // MARK: Aides

    private func setRecurrence(_ entry: inout ParsedEntry, _ rule: RecurrenceRule) {
        var rule = rule
        if let basis = entry.recurrence?.basis { rule.basis = basis }
        entry.recurrence = rule
    }

    private func nextWeekday(_ weekday: Int, from: DayDate, allowToday: Bool) -> DayDate {
        var d = allowToday ? from : from.adding(days: 1)
        for _ in 0..<7 {
            if d.weekday == weekday { return d }
            d = d.adding(days: 1)
        }
        return d
    }

    private func nextOccurrence(month: Int, day: Int) -> DayDate? {
        var candidate = DayDate(year: today.year, month: month, day: 1)
        guard (1...12).contains(month), day >= 1, day <= candidate.daysInMonth else { return nil }
        candidate = DayDate(year: today.year, month: month, day: day)
        if candidate < today { candidate = DayDate(year: today.year + 1, month: month, day: day) }
        return candidate
    }

    private func resolveProject(_ name: String) -> EntityID? {
        let needle = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        func fold(_ s: String) -> String { s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil) }
        if let exact = projects.first(where: { fold($0.name) == needle }) { return exact.id }
        if let prefix = projects.first(where: { fold($0.name).hasPrefix(needle) }) { return prefix.id }
        let compact = needle.replacingOccurrences(of: " ", with: "")
        return projects.first { fold($0.name).replacingOccurrences(of: " ", with: "").hasPrefix(compact) }?.id
    }
}
