import SwiftUI

struct SettingsSidebarView: View {
    @Binding var selectedPane: SettingsPane?

    var body: some View {
        List(selection: $selectedPane) {
            ForEach(SettingsPane.sidebarPanes) { pane in
                Label(pane.title, systemImage: pane.systemImage)
                    .tag(Optional(pane))
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }
}
