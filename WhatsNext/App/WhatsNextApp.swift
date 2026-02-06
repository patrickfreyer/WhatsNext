import SwiftUI

@main
struct WhatsNextApp: App {
    @StateObject private var viewModel = MenuBarViewModel()

    init() {
        debugLog("WhatsNext app started")
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            Image(systemName: "checklist")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
