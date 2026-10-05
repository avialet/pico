import SwiftUI
import PicoCore

struct SidebarView: View {
    @Environment(AppState.self) private var state
    @State private var renamingProject: Project?
    @State private var renamingArea: Area?
    @State private var renameText = ""

    var body: some View {
        @Bindable var state = state
        List(selection: $state.selection) {
            Section {
                smartRow(.inbox, count: state.inboxCount)
                smartRow(.today, count: state.todayCount)
                smartRow(.upcoming)
                smartRow(.anytime)
                smartRow(.someday)
                smartRow(.logbook)
            }
            let orphans = state.activeProjects.filter { $0.areaId == nil }
            if !orphans.isEmpty {
                Section("Projets") {
                    ForEach(orphans) { projectRow($0) }
                }
            }
            ForEach(state.areas) { area in
                Section {
                    ForEach(state.activeProjects.filter { $0.areaId == area.id }) { projectRow($0) }
                } header: {
                    Label(area.name, systemImage: area.icon ?? "square.grid.2x2")
                        .contextMenu {
                            Button("Renommer") { renameText = area.name; renamingArea = area }
                            Button("Nouveau projet ici") {
                                state.run { try state.projects.createProject("Nouveau projet", areaId: area.id) }
                            }
                            Divider()
                            Button("Supprimer la zone", role: .destructive) { state.deleteArea(area.id) }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Menu {
                    Button("Nouveau projet", systemImage: "folder.badge.plus") { state.newProject() }
                    Button("Nouvelle zone", systemImage: "square.grid.2x2") { state.newArea() }
                } label: {
                    Label("Nouvelle liste", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
            }
            .padding(8)
        }
        .alert("Renommer", isPresented: Binding(get: { renamingProject != nil || renamingArea != nil },
                                               set: { if !$0 { renamingProject = nil; renamingArea = nil } })) {
            TextField("Nom", text: $renameText)
            Button("OK") {
                if let p = renamingProject { state.rename(project: p, to: renameText) }
                if let a = renamingArea { state.rename(area: a, to: renameText) }
                renamingProject = nil; renamingArea = nil
            }
            Button("Annuler", role: .cancel) { renamingProject = nil; renamingArea = nil }
        }
    }

    private func smartRow(_ item: SidebarItem, count: Int = 0) -> some View {
        Label(item.title, systemImage: item.systemImage)
            .badge(count > 0 ? count : 0)
            .tag(item)
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
                case .project: break
                }
                return true
            }
    }

    private func projectRow(_ project: Project) -> some View {
        HStack(spacing: 6) {
            ProjectProgressCircle(projectId: project.id, size: 14)
            Text(project.name)
        }
        .tag(SidebarItem.project(project.id))
        .contextMenu {
            Button("Renommer") { renameText = project.name; renamingProject = project }
            Button("Terminer le projet") { state.completeProject(project.id) }
            Divider()
            Button("Supprimer", role: .destructive) { state.deleteProject(project.id) }
        }
        .dropDestination(for: String.self) { ids, _ in
            let todoIds = Set(ids.compactMap { $0.hasPrefix("todo:") ? EntityID(String($0.dropFirst(5))) : nil })
            guard !todoIds.isEmpty else { return false }
            state.move(ids: todoIds, toProject: project.id)
            return true
        }
    }
}

/// Cercle d'avancement d'un projet (style Things).
struct ProjectProgressCircle: View {
    @Environment(AppState.self) private var state
    let projectId: EntityID
    var size: CGFloat = 16

    var body: some View {
        let progress: (done: Int, total: Int) = (try? state.projects.progress(of: projectId)) ?? (done: 0, total: 0)
        let fraction = progress.total == 0 ? 0 : Double(progress.done) / Double(progress.total)
        ZStack {
            Circle().strokeBorder(.tint, lineWidth: 1.5)
            Circle()
                .trim(from: 0, to: fraction)
                .rotation(.degrees(-90))
                .fill(.tint)
                .padding(2.5)
        }
        .frame(width: size, height: size)
    }
}
