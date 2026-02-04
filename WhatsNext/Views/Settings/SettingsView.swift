import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @StateObject private var settingsVM = SettingsViewModel()

    var body: some View {
        TabView(selection: $settingsVM.selectedTab) {
            GeneralSettingsView(viewModel: settingsVM)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            SourceSettingsView(viewModel: settingsVM)
                .tabItem {
                    Label("Sources", systemImage: "folder")
                }
                .tag(SettingsTab.sources)

            ExplorationSettingsView(viewModel: settingsVM)
                .tabItem {
                    Label("Exploration", systemImage: "magnifyingglass")
                }
                .tag(SettingsTab.exploration)

            PromptSettingsView(viewModel: settingsVM)
                .tabItem {
                    Label("Prompt", systemImage: "text.bubble")
                }
                .tag(SettingsTab.prompt)
        }
        .frame(width: 550, height: 450)
    }
}

#Preview {
    SettingsView(viewModel: MenuBarViewModel())
}
