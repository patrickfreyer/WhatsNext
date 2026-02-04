import SwiftUI

// MARK: - Exploration Settings View

struct ExplorationSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedFolderIndex: Int?

    private let availableStrategies: [(id: String, name: String, description: String)] = [
        ("git-status", "Git Status", "Check for uncommitted changes and branch status"),
        ("todo-scanner", "TODO Scanner", "Find TODO, FIXME, and HACK comments"),
        ("recent-changes", "Recent Changes", "Identify recently modified files"),
        ("project-structure", "Project Structure", "Analyze project layout and dependencies")
    ]

    var body: some View {
        HSplitView {
            // Folder list
            folderListView
                .frame(minWidth: 150, maxWidth: 200)

            // Exploration settings for selected folder
            if let index = selectedFolderIndex,
               index < viewModel.sources.folders.count {
                folderExplorationSettings(for: index)
            } else {
                noSelectionView
            }
        }
    }

    // MARK: - Folder List

    private var folderListView: some View {
        VStack(alignment: .leading) {
            Text("Folders")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            List(selection: $selectedFolderIndex) {
                ForEach(Array(viewModel.sources.folders.enumerated()), id: \.offset) { index, folder in
                    HStack {
                        Image(systemName: folder.isEnabled ? "folder.fill" : "folder")
                            .foregroundColor(folder.isEnabled ? .accentColor : .secondary)
                        Text(folder.name)
                            .lineLimit(1)
                    }
                    .tag(index)
                }
            }
            .listStyle(.sidebar)
        }
    }

    // MARK: - No Selection View

    private var noSelectionView: some View {
        VStack {
            Spacer()
            Text("Select a folder to configure exploration")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Folder Exploration Settings

    private func folderExplorationSettings(for index: Int) -> some View {
        let binding = Binding<FolderSourceConfiguration>(
            get: { viewModel.sources.folders[index] },
            set: { viewModel.sources.folders[index] = $0 }
        )

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(binding.wrappedValue.name)
                        .font(.title2)
                    Text(binding.wrappedValue.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Strategies
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exploration Strategies")
                        .font(.headline)

                    ForEach(availableStrategies, id: \.id) { strategy in
                        strategyToggle(strategy: strategy, config: binding)
                    }
                }

                Divider()

                // Depth & Limits
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scan Settings")
                        .font(.headline)

                    Stepper(
                        "Max depth: \(binding.wrappedValue.exploration.maxDepth) levels",
                        value: binding.exploration.maxDepth,
                        in: 1...10
                    )

                    Stepper(
                        "Max files: \(binding.wrappedValue.exploration.maxFilesToAnalyze)",
                        value: binding.exploration.maxFilesToAnalyze,
                        in: 10...200,
                        step: 10
                    )
                }

                Divider()

                // File Patterns
                VStack(alignment: .leading, spacing: 12) {
                    Text("File Patterns")
                        .font(.headline)

                    Text("Include patterns (one per line):")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: Binding(
                        get: { binding.wrappedValue.exploration.filePatterns.joined(separator: "\n") },
                        set: { binding.wrappedValue.exploration.filePatterns = $0.split(separator: "\n").map(String.init) }
                    ))
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 60)
                    .border(Color.secondary.opacity(0.3))

                    Text("Exclude patterns (one per line):")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: Binding(
                        get: { binding.wrappedValue.exploration.excludePatterns.joined(separator: "\n") },
                        set: { binding.wrappedValue.exploration.excludePatterns = $0.split(separator: "\n").map(String.init) }
                    ))
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 60)
                    .border(Color.secondary.opacity(0.3))
                }

                // Save button
                Button("Save Changes") {
                    viewModel.saveSources()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private func strategyToggle(
        strategy: (id: String, name: String, description: String),
        config: Binding<FolderSourceConfiguration>
    ) -> some View {
        let isEnabled = Binding<Bool>(
            get: { config.wrappedValue.exploration.enabledStrategies.contains(strategy.id) },
            set: { enabled in
                if enabled {
                    if !config.wrappedValue.exploration.enabledStrategies.contains(strategy.id) {
                        config.wrappedValue.exploration.enabledStrategies.append(strategy.id)
                    }
                } else {
                    config.wrappedValue.exploration.enabledStrategies.removeAll { $0 == strategy.id }
                }
            }
        )

        return HStack {
            Toggle("", isOn: isEnabled)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(strategy.name)
                    .font(.body)
                Text(strategy.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    ExplorationSettingsView(viewModel: SettingsViewModel())
}
