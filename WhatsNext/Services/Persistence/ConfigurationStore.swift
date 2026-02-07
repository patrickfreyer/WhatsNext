import Foundation

// MARK: - Configuration Store

/// Handles persistence of app configuration to JSON files
final class ConfigurationStore: ObservableObject {
    static let shared = ConfigurationStore()

    @Published private(set) var configuration: AppConfiguration

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var configURL: URL {
        appSupportDirectory.appendingPathComponent("config.json")
    }

    private var appSupportDirectory: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("WhatsNext")

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appSupport.path) {
            try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }

        return appSupport
    }

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Compute config URL directly to avoid accessing computed property before init completes
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("WhatsNext")
        if !FileManager.default.fileExists(atPath: appSupport.path) {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        let url = appSupport.appendingPathComponent("config.json")

        // Load existing configuration or use default
        configuration = Self.loadConfiguration(from: url, using: decoder) ?? .default
    }

    // MARK: - Public Methods

    /// Update the entire configuration
    func updateConfiguration(_ newConfig: AppConfiguration) {
        configuration = newConfig
        save()
    }

    /// Update general settings
    func updateGeneral(_ general: GeneralConfiguration) {
        configuration.general = general
        save()
    }

    /// Update Claude settings
    func updateClaude(_ claude: ClaudeConfiguration) {
        configuration.claude = claude
        save()
    }

    /// Update sources configuration
    func updateSources(_ sources: SourcesConfiguration) {
        configuration.sources = sources
        save()
    }

    // MARK: - Folder Sources

    func addFolderSource(_ folder: FolderSourceConfiguration) {
        configuration.sources.folders.append(folder)
        save()
    }

    func updateFolderSource(_ folder: FolderSourceConfiguration) {
        if let index = configuration.sources.folders.firstIndex(where: { $0.id == folder.id }) {
            configuration.sources.folders[index] = folder
            save()
        }
    }

    func removeFolderSource(id: UUID) {
        configuration.sources.folders.removeAll { $0.id == id }
        save()
    }

    // MARK: - Website Sources

    func addWebsiteSource(_ website: WebsiteSourceConfiguration) {
        configuration.sources.websites.append(website)
        save()
    }

    func updateWebsiteSource(_ website: WebsiteSourceConfiguration) {
        if let index = configuration.sources.websites.firstIndex(where: { $0.id == website.id }) {
            configuration.sources.websites[index] = website
            save()
        }
    }

    func removeWebsiteSource(id: UUID) {
        configuration.sources.websites.removeAll { $0.id == id }
        save()
    }

    // MARK: - Reminders & Mail

    func updateRemindersSource(_ reminders: RemindersSourceConfiguration) {
        configuration.sources.reminders = reminders
        save()
    }

    func updateMailSource(_ mail: MailSourceConfiguration) {
        configuration.sources.mail = mail
        save()
    }

    // MARK: - Reset

    func resetToDefaults() {
        configuration = .default
        save()
    }

    // MARK: - Private Methods

    private func save() {
        do {
            let data = try encoder.encode(configuration)
            try data.write(to: configURL, options: .atomic)
        } catch {
            print("Failed to save configuration: \(error)")
        }
    }

    private static func loadConfiguration(from url: URL, using decoder: JSONDecoder) -> AppConfiguration? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(AppConfiguration.self, from: data)
        } catch {
            print("Failed to load configuration: \(error)")
            return nil
        }
    }
}

// MARK: - Task Store

/// Handles persistence of suggested tasks
final class TaskStore: ObservableObject {
    static let shared = TaskStore()

    @Published private(set) var tasks: [SuggestedTask] = []
    @Published private(set) var lastRefreshed: Date?

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var tasksURL: URL {
        appSupportDirectory.appendingPathComponent("tasks.json")
    }

    private var appSupportDirectory: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("WhatsNext")

        if !fileManager.fileExists(atPath: appSupport.path) {
            try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }

        return appSupport
    }

    /// Resolved tasks older than this are pruned
    private let taskRetentionDays = 5

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        loadTasks()
        pruneOldTasks()
    }

    // MARK: - Public Methods

    /// Merge new tasks with existing ones, preserving statuses
    func mergeTasks(_ newTasks: [SuggestedTask]) {
        let now = Date()
        var merged: [SuggestedTask] = []

        // Build a lookup of existing tasks by normalized title
        let existingByTitle = Dictionary(
            tasks.map { ($0.normalizedTitle, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Build set of dismissed normalized titles to avoid re-adding
        let dismissedTitles = Set(
            tasks.filter { $0.status == .dismissed }.map { $0.normalizedTitle }
        )

        // Track which existing tasks have been matched
        var matchedExistingIDs = Set<UUID>()

        for newTask in newTasks {
            let normalized = newTask.normalizedTitle

            // Skip if this task was previously dismissed
            if dismissedTitles.contains(normalized) {
                continue
            }

            if let existing = existingByTitle[normalized] {
                // Match found -- update the existing task's updatedAt, keep its status
                var updated = existing
                updated.updatedAt = now
                // Also update fields that may have changed from AI
                updated.description = newTask.description
                updated.priority = newTask.priority
                updated.estimatedMinutes = newTask.estimatedMinutes
                updated.actionPlan = newTask.actionPlan
                updated.suggestedCommand = newTask.suggestedCommand
                updated.sourceInfo = newTask.sourceInfo
                merged.append(updated)
                matchedExistingIDs.insert(existing.id)
            } else {
                // Truly new task
                var task = newTask
                task.status = .pending
                task.updatedAt = now
                merged.append(task)
            }
        }

        // Keep existing inProgress and completed tasks that weren't matched
        for existing in tasks {
            if !matchedExistingIDs.contains(existing.id) &&
               (existing.status == .inProgress || existing.status == .completed) {
                merged.append(existing)
            }
        }

        // Sort: inProgress first, then pending by priority, then completed
        merged.sort { a, b in
            if a.status.sortOrder != b.status.sortOrder {
                return a.status.sortOrder < b.status.sortOrder
            }
            return a.priority.sortOrder < b.priority.sortOrder
        }

        tasks = merged
        lastRefreshed = now
        save()
    }

    func addTask(_ task: SuggestedTask) {
        tasks.append(task)
        tasks.sort {
            if $0.status.sortOrder != $1.status.sortOrder {
                return $0.status.sortOrder < $1.status.sortOrder
            }
            return $0.priority.sortOrder < $1.priority.sortOrder
        }
        save()
    }

    func updateTaskStatus(id: UUID, status: TaskStatus) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].status = status
            tasks[index].updatedAt = Date()
            // Re-sort after status change
            tasks.sort {
                if $0.status.sortOrder != $1.status.sortOrder {
                    return $0.status.sortOrder < $1.status.sortOrder
                }
                return $0.priority.sortOrder < $1.priority.sortOrder
            }
            save()
        }
    }

    func removeTask(id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }

    func clearAllTasks() {
        tasks = []
        save()
    }

    // MARK: - Private Methods

    private func save() {
        let container = TaskContainer(tasks: tasks, lastRefreshed: lastRefreshed)
        do {
            let data = try encoder.encode(container)
            try data.write(to: tasksURL, options: .atomic)
        } catch {
            print("Failed to save tasks: \(error)")
        }
    }

    private func loadTasks() {
        guard fileManager.fileExists(atPath: tasksURL.path) else { return }

        do {
            let data = try Data(contentsOf: tasksURL)
            let container = try decoder.decode(TaskContainer.self, from: data)
            tasks = container.tasks
            lastRefreshed = container.lastRefreshed
        } catch {
            print("Failed to load tasks: \(error)")
        }
    }
}

// MARK: - Task Container

private struct TaskContainer: Codable {
    var tasks: [SuggestedTask]
    var lastRefreshed: Date?
}
