import SwiftUI

// MARK: - Source Settings View

struct SourceSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Folders Section
                foldersSection

                Divider()

                // Websites Section
                websitesSection

                Divider()

                // Reminders Section
                remindersSection

                Divider()

                // Mail Section
                mailSection
            }
            .padding()
        }
    }

    // MARK: - Folders Section

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Folders", systemImage: "folder")
                .font(.headline)

            ForEach(viewModel.sources.folders) { folder in
                HStack {
                    Toggle("", isOn: Binding(
                        get: { folder.isEnabled },
                        set: { _ in viewModel.toggleFolder(folder) }
                    ))
                    .labelsHidden()

                    VStack(alignment: .leading) {
                        Text(folder.name)
                            .font(.body)
                        Text(folder.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        if let index = viewModel.sources.folders.firstIndex(where: { $0.id == folder.id }) {
                            viewModel.removeFolder(at: IndexSet(integer: index))
                        }
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
            }

            // Add new folder
            HStack {
                TextField("Folder path...", text: $viewModel.newFolderPath)
                    .textFieldStyle(.roundedBorder)

                TextField("Name (optional)", text: $viewModel.newFolderName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)

                Button("Add") {
                    viewModel.addFolder()
                }
                .disabled(viewModel.newFolderPath.isEmpty)
            }

            Text("Tip: Use ~ for home directory (e.g., ~/Projects/MyApp)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Websites Section

    private var websitesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Websites", systemImage: "globe")
                .font(.headline)

            ForEach(viewModel.sources.websites) { website in
                HStack {
                    Toggle("", isOn: Binding(
                        get: { website.isEnabled },
                        set: { _ in viewModel.toggleWebsite(website) }
                    ))
                    .labelsHidden()

                    VStack(alignment: .leading) {
                        Text(website.name)
                            .font(.body)
                        Text(website.url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        if let index = viewModel.sources.websites.firstIndex(where: { $0.id == website.id }) {
                            viewModel.removeWebsite(at: IndexSet(integer: index))
                        }
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
            }

            // Add new website
            HStack {
                TextField("https://...", text: $viewModel.newWebsiteURL)
                    .textFieldStyle(.roundedBorder)

                TextField("Name (optional)", text: $viewModel.newWebsiteName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)

                Button("Add") {
                    viewModel.addWebsite()
                }
                .disabled(viewModel.newWebsiteURL.isEmpty)
            }
        }
    }

    // MARK: - Reminders Section

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Reminders", systemImage: "checklist")
                .font(.headline)

            Toggle("Enable Reminders", isOn: $viewModel.sources.reminders.isEnabled)

            if viewModel.sources.reminders.isEnabled {
                Toggle("Include completed reminders", isOn: $viewModel.sources.reminders.includeCompleted)
                    .padding(.leading, 20)

                Text("Lists: All lists (or specify in config.json)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }

            Button("Save Changes") {
                viewModel.saveSources()
            }
        }
    }

    // MARK: - Mail Section

    private var mailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Mail", systemImage: "envelope")
                .font(.headline)

            Toggle("Enable Mail", isOn: $viewModel.sources.mail.isEnabled)

            if viewModel.sources.mail.isEnabled {
                Toggle("Only unread emails", isOn: $viewModel.sources.mail.onlyUnread)
                    .padding(.leading, 20)

                Toggle("Only flagged emails", isOn: $viewModel.sources.mail.onlyFlagged)
                    .padding(.leading, 20)

                Stepper(
                    "Fetch up to \(viewModel.sources.mail.maxEmailsToFetch) emails",
                    value: $viewModel.sources.mail.maxEmailsToFetch,
                    in: 5...100,
                    step: 5
                )
                .padding(.leading, 20)

                Text("Mailboxes: \(viewModel.sources.mail.mailboxNames.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }

            Button("Save Changes") {
                viewModel.saveSources()
            }
        }
    }
}

#Preview {
    SourceSettingsView(viewModel: SettingsViewModel())
}
