import SwiftUI
import PicoCore

struct MainWindow: View {
    @Environment(AppState.self) private var state
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var state = state
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            TodoListView()
                .inspector(isPresented: $state.showInspector) {
                    TodoInspector()
                        .inspectorColumnWidth(min: 280, ideal: 320, max: 420)
                }
        }
        .searchable(text: $state.searchText, placement: .toolbar, prompt: "Rechercher")
        .onChange(of: state.searchText) { _, _ in state.reload() }
        .onChange(of: state.selection) { _, _ in
            state.searchText = ""
            state.selectedTodoIds = []
            state.editingTodoId = nil
            state.reload()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nouvelle tache", systemImage: "plus") { state.newTodo() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            ToolbarItem {
                Button("Inspecteur", systemImage: "sidebar.trailing") { state.showInspector.toggle() }
            }
        }
    }
}
