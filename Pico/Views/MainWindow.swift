import SwiftUI
import PicoCore

struct MainWindow: View {
    @Environment(AppState.self) private var state

    private var showPanel: Bool { state.showInspector && !state.selectedTodoIds.isEmpty }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 238)
            ZStack {
                AmbientBackground(accent: state.selection.accent)
                    .animation(.easeInOut(duration: 0.6), value: state.selection)
                HStack(spacing: 0) {
                    TodoListView()
                        .frame(minWidth: 360, maxWidth: .infinity)
                        .clipped()
                    if showPanel {
                        InspectorPanel()
                            .frame(width: 340)
                            .layoutPriority(1)
                            .padding(.top, 40)
                            .padding([.bottom, .trailing], 16)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .background(Theme.paper)
        .tint(state.selection.accent)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: showPanel)
        .onChange(of: state.searchText) { _, _ in state.reload() }
        .onChange(of: state.selection) { _, _ in
            state.searchText = ""
            state.selectedTodoIds = []
            state.editingTodoId = nil
            state.reload()
        }
    }
}
