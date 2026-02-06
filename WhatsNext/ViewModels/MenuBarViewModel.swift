import Combine
import Foundation
import SwiftUI

// MARK: - Menu Bar View Model

@MainActor
final class MenuBarViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var tasks: [SuggestedTask] = []
    @Published var isRefreshing = false
    @Published var lastRefreshDate: Date?
    @Published var errorMessage: String?
    @Published var showingSettings = false

    // MARK: - Dependencies

    private let configStore = ConfigurationStore.shared
    private let taskStore = TaskStore.shared
    private let sourceManager = SourceManager.shared
    private let claudeService = ClaudeService.shared
    private let sessionLauncher = ClaudeSessionLauncher.shared

    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var configuration: AppConfiguration {
        configStore.configuration
    }

    var maxTasksToShow: Int {
        configStore.configuration.general.maxTasksToShow
    }

    var displayedTasks: [SuggestedTask] {
        Array(tasks.prefix(maxTasksToShow))
    }

    var hasMoreTasks: Bool {
        tasks.count > maxTasksToShow
    }

    var refreshIntervalMinutes: Int {
        configStore.configuration.general.refreshIntervalMinutes
    }

    // MARK: - Initialization

    init() {
        // Load persisted tasks
        tasks = taskStore.tasks
        lastRefreshDate = taskStore.lastRefreshed

        // Subscribe to task store changes
        taskStore.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTasks in
                self?.tasks = newTasks
            }
            .store(in: &cancellables)

        // Start refresh timer
        setupRefreshTimer()
    }

    // MARK: - Public Methods

    /// Refresh tasks from all sources
    func refresh() async {
        guard !isRefreshing else {
            print("[WhatsNext] Refresh already in progress, skipping")
            return
        }

        print("[WhatsNext] Starting refresh...")
        isRefreshing = true
        errorMessage = nil

        do {
            // Fetch from all sources
            print("[WhatsNext] Fetching from sources...")
            let (items, explorations) = await sourceManager.fetchAllItems()
            print("[WhatsNext] Fetched \(items.count) items and \(explorations.count) explorations")

            // Analyze with Claude
            print("[WhatsNext] Calling Claude for analysis...")
            let suggestedTasks = try await claudeService.analyzeSources(
                items: items,
                explorations: explorations,
                config: configStore.configuration.claude
            )
            print("[WhatsNext] Claude returned \(suggestedTasks.count) tasks")

            // Update tasks
            taskStore.updateTasks(suggestedTasks)
            lastRefreshDate = Date()
            print("[WhatsNext] Refresh completed successfully")

        } catch {
            print("[WhatsNext] Refresh failed: \(error)")
            errorMessage = error.localizedDescription
        }

        isRefreshing = false
    }

    /// Execute a task in Claude Code
    func executeTask(_ task: SuggestedTask) {
        sessionLauncher.executeTask(task)
    }

    /// Execute a specific step of a task
    func executeStep(_ step: ActionStep, of task: SuggestedTask) {
        sessionLauncher.executeStep(step, task: task)
    }

    /// Dismiss a task (remove from list)
    func dismissTask(_ task: SuggestedTask) {
        taskStore.removeTask(id: task.id)
    }

    /// Clear all tasks
    func clearAllTasks() {
        taskStore.clearAllTasks()
    }

    /// Open settings window
    func openSettings() {
        // Try multiple approaches for opening settings
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        // Bring app to front
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Quit the application
    func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Private Methods

    private func setupRefreshTimer() {
        refreshTimer?.invalidate()

        let interval = TimeInterval(refreshIntervalMinutes * 60)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }
}

// MARK: - Settings View Model

@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var general: GeneralConfiguration
    @Published var claude: ClaudeConfiguration
    @Published var sources: SourcesConfiguration

    @Published var newFolderPath: String = ""
    @Published var newFolderName: String = ""
    @Published var newWebsiteURL: String = ""
    @Published var newWebsiteName: String = ""

    @Published var selectedTab: SettingsTab = .general
    @Published var isSaving = false
    @Published var showingSaveConfirmation = false

    // MARK: - Dependencies

    private let configStore = ConfigurationStore.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        let config = configStore.configuration
        self.general = config.general
        self.claude = config.claude
        self.sources = config.sources

        // Subscribe to config changes
        configStore.$configuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] config in
                self?.general = config.general
                self?.claude = config.claude
                self?.sources = config.sources
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    func saveGeneral() {
        configStore.updateGeneral(general)
        showingSaveConfirmation = true
    }

    func saveClaude() {
        configStore.updateClaude(claude)
        showingSaveConfirmation = true
    }

    func saveSources() {
        configStore.updateSources(sources)
        SourceManager.shared.refreshProviders()
        showingSaveConfirmation = true
    }

    // MARK: - Folder Management

    func addFolder() {
        guard !newFolderPath.isEmpty else { return }

        let name = newFolderName.isEmpty ? URL(fileURLWithPath: newFolderPath).lastPathComponent : newFolderName
        let folder = FolderSourceConfiguration(name: name, path: newFolderPath)

        sources.folders.append(folder)
        saveSources()

        newFolderPath = ""
        newFolderName = ""
    }

    func removeFolder(at offsets: IndexSet) {
        sources.folders.remove(atOffsets: offsets)
        saveSources()
    }

    func toggleFolder(_ folder: FolderSourceConfiguration) {
        if let index = sources.folders.firstIndex(where: { $0.id == folder.id }) {
            sources.folders[index].isEnabled.toggle()
            saveSources()
        }
    }

    // MARK: - Website Management

    func addWebsite() {
        guard !newWebsiteURL.isEmpty else { return }

        let name = newWebsiteName.isEmpty ? newWebsiteURL : newWebsiteName
        let website = WebsiteSourceConfiguration(name: name, url: newWebsiteURL)

        sources.websites.append(website)
        saveSources()

        newWebsiteURL = ""
        newWebsiteName = ""
    }

    func removeWebsite(at offsets: IndexSet) {
        sources.websites.remove(atOffsets: offsets)
        saveSources()
    }

    func toggleWebsite(_ website: WebsiteSourceConfiguration) {
        if let index = sources.websites.firstIndex(where: { $0.id == website.id }) {
            sources.websites[index].isEnabled.toggle()
            saveSources()
        }
    }

    // MARK: - Reset

    func resetToDefaults() {
        configStore.resetToDefaults()
        let config = configStore.configuration
        general = config.general
        claude = config.claude
        sources = config.sources
    }
}

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case sources = "Sources"
    case exploration = "Exploration"
    case prompt = "Prompt"

    var icon: String {
        switch self {
        case .general: return "gear"
        case .sources: return "folder"
        case .exploration: return "magnifyingglass"
        case .prompt: return "text.bubble"
        }
    }
}
