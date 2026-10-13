import SwiftUI
import PicoCore

struct SidebarView: View {
    @Environment(AppState.self) private var state
    @FocusState private var searchFocused: Bool
    @State private var renamingProject: Project?
    @State private var renamingArea: Area?
    @State private var renameText = ""

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 0) {
            brand
            searchField
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(SidebarItem.smartLists, id: \.self) { item in
                        SidebarRow(item: item, title: item.title, count: count(for: item))
                        if item == .today || item == .someday { Spacer().frame(height: 8) }
                    }
                    let orphans = state.activeProjects.filter { $0.areaId == nil }
                    if !orphans.isEmpty {
                        groupHeader("Projets")
                        ForEach(orphans) { projectRow($0) }
                    }
                    ForEach(state.areas) { area in
                        groupHeader(area.name)
                            .contextMenu {
                                Button("Renommer…") { renameText = area.name; renamingArea = area }
                                Button("Nouveau projet dans cette zone") { state.newProject(in: area.id) }
                                Divider()
                                Button("Supprimer la zone", role: .destructive) { state.deleteArea(area.id) }
                            }
                        ForEach(state.activeProjects.filter { $0.areaId == area.id }) { projectRow($0) }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.never)
            UpdateBanner()
            footer
        }
        .background(Theme.sidebar)
        .onChange(of: state.searchFocusRequest) { _, _ in searchFocused = true }
        .alert("Renommer", isPresented: Binding(
            get: { renamingProject != nil || renamingArea != nil },
            set: { if !$0 { renamingProject = nil; renamingArea = nil } })
        ) {
            TextField("Nom", text: $renameText)
            Button("Renommer") {
                if let p = renamingProject { state.rename(project: p, to: renameText) }
                if let a = renamingArea { state.rename(area: a, to: renameText) }
                renamingProject = nil; renamingArea = nil
            }
            Button("Annuler", role: .cancel) { renamingProject = nil; renamingArea = nil }
        }
    }

    private var brand: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("pico").font(Theme.display(26, weight: .heavy)).foregroundStyle(Theme.ink)
            Text(".").font(Theme.display(26, weight: .heavy)).foregroundStyle(state.selection.accent)
                .animation(.easeInOut, value: state.selection)
        }
        .padding(.leading, 22)
        .padding(.top, 46)
        .padding(.bottom, 14)
    }

    private var searchField: some View {
        @Bindable var state = state
        return HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.inkSoft)
            TextField("Rechercher", text: $state.searchText)
                .textFieldStyle(.plain)
                .font(Theme.ui(13))
                .focused($searchFocused)
                .onExitCommand { state.searchText = ""; searchFocused = false }
            if !state.searchText.isEmpty {
                Button { state.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.inkFaint)
                }.buttonStyle(.plain)
            } else {
                Text("⌘F").font(Theme.ui(10.5, weight: .semibold)).foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.ink.opacity(searchFocused ? 0.08 : 0.05)))
        .padding(.horizontal, 12)
    }

    private func groupHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Theme.ui(10.5, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(Theme.inkFaint)
            .padding(.leading, 12)
            .padding(.top, 18)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }

    private func projectRow(_ project: Project) -> some View {
        SidebarRow(item: .project(project.id), title: project.name, count: 0)
            .contextMenu {
                Button("Renommer…") { renameText = project.name; renamingProject = project }
                Menu("Déplacer dans la zone") {
                    Button("Aucune") { var p = project; p.areaId = nil; state.saveProject(p) }
                    ForEach(state.areas) { a in
                        Button(a.name) { var p = project; p.areaId = a.id; state.saveProject(p) }
                    }
                }
                Button("Terminer le projet") { state.completeProject(project.id) }
                Divider()
                Button("Supprimer", role: .destructive) { state.deleteProject(project.id) }
            }
    }

    private var footer: some View {
        Menu {
            Button("Nouveau projet", systemImage: "folder.badge.plus") { state.newProject() }
            Button("Nouvelle zone", systemImage: "square.grid.2x2") { state.newArea() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                Text("Nouvelle liste").font(Theme.ui(13, weight: .medium))
            }
            .foregroundStyle(Theme.inkSoft)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private func count(for item: SidebarItem) -> Int {
        switch item {
        case .inbox: state.inboxCount
        case .today: state.todayCount
        default: 0
        }
    }
}

/// Ligne de la barre laterale : icone en pastille de couleur, titre, compteur.
struct SidebarRow: View {
    @Environment(AppState.self) private var state
    let item: SidebarItem
    let title: String
    let count: Int
    @State private var hovering = false
    @State private var targeted = false

    private var selected: Bool { state.selection == item }

    var body: some View {
        Button { state.selection = item } label: {
            HStack(spacing: 10) {
                icon
                Text(title)
                    .font(Theme.ui(13.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if count > 0 {
                    Text("\(count)")
                        .font(Theme.ui(11.5, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(selected ? item.accent : Theme.inkSoft)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6.5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? item.accent.opacity(0.16)
                          : targeted ? item.accent.opacity(0.24)
                          : hovering ? Theme.ink.opacity(0.05) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: selected)
        .animation(.easeOut(duration: 0.12), value: targeted)
        .dropDestination(for: String.self) { ids, _ in
            let todoIds = Set(ids.compactMap { $0.hasPrefix("todo:") ? EntityID(String($0.dropFirst(5))) : nil })
            guard !todoIds.isEmpty else { return false }
            switch item {
            case .inbox: state.move(ids: todoIds, toProject: nil); state.plan(nil, ids: todoIds)
            case .today: state.plan(state.today, ids: todoIds)
            case .upcoming: state.plan(state.today.adding(days: 1), ids: todoIds)
            case .anytime: state.plan(nil, ids: todoIds)
            case .someday: state.moveToSomeday(ids: todoIds)
            case .logbook: state.toggleComplete(todoIds)
            case .project(let id): state.move(ids: todoIds, toProject: id)
            }
            return true
        } isTargeted: { targeted = $0 }
    }

    @ViewBuilder
    private var icon: some View {
        if case .project(let id) = item {
            ProgressRing(fraction: state.projectProgress[id]?.fraction ?? 0, color: item.accent, size: 16, lineWidth: 2.2)
                .frame(width: 22, height: 22)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(item.accent.gradient)
                Image(systemName: item.systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 22, height: 22)
            .shadow(color: item.accent.opacity(0.35), radius: selected ? 4 : 0, y: 1)
        }
    }
}
