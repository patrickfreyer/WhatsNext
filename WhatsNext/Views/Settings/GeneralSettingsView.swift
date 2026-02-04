import SwiftUI

// MARK: - General Settings View

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $viewModel.general.launchAtLogin)
                    .help("Automatically start What's Next when you log in")
            }

            Section {
                Stepper(
                    "Refresh every \(viewModel.general.refreshIntervalMinutes) minutes",
                    value: $viewModel.general.refreshIntervalMinutes,
                    in: 5...120,
                    step: 5
                )
                .help("How often to analyze sources and suggest new tasks")

                Stepper(
                    "Show up to \(viewModel.general.maxTasksToShow) tasks",
                    value: $viewModel.general.maxTasksToShow,
                    in: 1...20
                )
                .help("Maximum number of tasks to display in the menu")
            }

            Section {
                Button("Save Changes") {
                    viewModel.saveGeneral()
                }
                .buttonStyle(.borderedProminent)

                if viewModel.showingSaveConfirmation {
                    Text("Settings saved!")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }

            Spacer()

            Section {
                Button("Reset to Defaults", role: .destructive) {
                    viewModel.resetToDefaults()
                }
            }
        }
        .padding()
    }
}

#Preview {
    GeneralSettingsView(viewModel: SettingsViewModel())
}
