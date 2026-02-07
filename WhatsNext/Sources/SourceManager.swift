import Foundation

// MARK: - Source Manager

/// Orchestrates all source providers and fetches data from configured sources
@MainActor
final class SourceManager: ObservableObject {
    static let shared = SourceManager()

    @Published private(set) var isLoading = false
    @Published private(set) var lastError: Error?
    @Published private(set) var lastFetchResults: [SourceFetchResult] = []

    private let configStore = ConfigurationStore.shared
    private let explorationEngine = ExplorationEngine.shared

    private var folderProviders: [FolderSourceProvider] = []
    private var websiteProviders: [WebsiteSourceProvider] = []
    private var remindersProvider: RemindersSourceProvider?
    private var mailProvider: MailSourceProvider?
    private var calendarProvider: CalendarSourceProvider?

    private init() {
        refreshProviders()
    }

    // MARK: - Public Methods

    /// Refresh all providers from current configuration
    func refreshProviders() {
        let config = configStore.configuration.sources

        // Folder providers
        folderProviders = config.folders
            .filter { $0.isEnabled }
            .map { FolderSourceProvider(configuration: $0) }

        // Website providers
        websiteProviders = config.websites
            .filter { $0.isEnabled }
            .map { WebsiteSourceProvider(configuration: $0) }

        // Reminders provider
        if config.reminders.isEnabled {
            remindersProvider = RemindersSourceProvider(configuration: config.reminders)
        } else {
            remindersProvider = nil
        }

        // Mail provider
        if config.mail.isEnabled {
            mailProvider = MailSourceProvider(configuration: config.mail)
        } else {
            mailProvider = nil
        }

        // Calendar provider
        if config.calendar.isEnabled {
            calendarProvider = CalendarSourceProvider(configuration: config.calendar)
        } else {
            calendarProvider = nil
        }
    }

    /// Fetch all items from all enabled sources
    func fetchAllItems() async -> ([SourceItem], [ExplorationResult]) {
        isLoading = true
        lastError = nil
        var allItems: [SourceItem] = []
        var allExplorations: [ExplorationResult] = []
        var results: [SourceFetchResult] = []

        // Fetch from folders with exploration
        for provider in folderProviders {
            let result = await fetchFromFolderProvider(provider)
            results.append(result)
            allItems.append(contentsOf: result.items)
            allExplorations.append(contentsOf: result.explorationResults)
        }

        // Fetch from websites
        for provider in websiteProviders {
            let result = await fetchFromProvider(provider)
            results.append(result)
            allItems.append(contentsOf: result.items)
        }

        // Fetch from reminders
        if let provider = remindersProvider {
            let result = await fetchFromProvider(provider)
            results.append(result)
            allItems.append(contentsOf: result.items)
        }

        // Fetch from mail
        if let provider = mailProvider {
            let result = await fetchFromProvider(provider)
            results.append(result)
            allItems.append(contentsOf: result.items)
        }

        // Fetch from calendar
        if let provider = calendarProvider {
            let result = await fetchFromProvider(provider)
            results.append(result)
            allItems.append(contentsOf: result.items)
        }

        lastFetchResults = results
        isLoading = false

        return (allItems, allExplorations)
    }

    /// Fetch from a specific source type
    func fetchFromSourceType(_ sourceType: SourceType) async -> SourceFetchResult {
        switch sourceType {
        case .folder:
            var items: [SourceItem] = []
            var explorations: [ExplorationResult] = []
            for provider in folderProviders {
                let result = await fetchFromFolderProvider(provider)
                items.append(contentsOf: result.items)
                explorations.append(contentsOf: result.explorationResults)
            }
            return SourceFetchResult(sourceType: .folder, sourceName: "All Folders", items: items, explorationResults: explorations)

        case .website:
            var items: [SourceItem] = []
            for provider in websiteProviders {
                let result = await fetchFromProvider(provider)
                items.append(contentsOf: result.items)
            }
            return SourceFetchResult(sourceType: .website, sourceName: "All Websites", items: items)

        case .reminders:
            if let provider = remindersProvider {
                return await fetchFromProvider(provider)
            }
            return SourceFetchResult(sourceType: .reminders, sourceName: "Reminders", error: SourceProviderError.notAvailable("Reminders not enabled"))

        case .mail:
            if let provider = mailProvider {
                return await fetchFromProvider(provider)
            }
            return SourceFetchResult(sourceType: .mail, sourceName: "Mail", error: SourceProviderError.notAvailable("Mail not enabled"))

        case .calendar:
            if let provider = calendarProvider {
                return await fetchFromProvider(provider)
            }
            return SourceFetchResult(sourceType: .calendar, sourceName: "Calendar", error: SourceProviderError.notAvailable("Calendar not enabled"))
        }
    }

    // MARK: - Permission Checking

    /// Check if all providers have required permissions
    func checkAllPermissions() async -> [SourceType: Bool] {
        var permissions: [SourceType: Bool] = [:]

        // Folders generally don't need special permissions (handled at OS level)
        permissions[.folder] = true

        // Websites don't need permissions
        permissions[.website] = true

        // Check reminders
        if let provider = remindersProvider {
            permissions[.reminders] = await provider.checkPermissions()
        } else {
            permissions[.reminders] = true
        }

        // Check mail
        if let provider = mailProvider {
            permissions[.mail] = await provider.checkPermissions()
        } else {
            permissions[.mail] = true
        }

        // Check calendar
        if let provider = calendarProvider {
            permissions[.calendar] = await provider.checkPermissions()
        } else {
            permissions[.calendar] = true
        }

        return permissions
    }

    /// Request permissions for a specific source type
    func requestPermissions(for sourceType: SourceType) async throws {
        switch sourceType {
        case .reminders:
            try await remindersProvider?.requestPermissions()
        case .mail:
            try await mailProvider?.requestPermissions()
        case .calendar:
            try await calendarProvider?.requestPermissions()
        default:
            break
        }
    }

    // MARK: - Private Methods

    private func fetchFromProvider(_ provider: any SourceProvider) async -> SourceFetchResult {
        do {
            let items = try await provider.fetchItems()
            return SourceFetchResult(
                sourceType: provider.sourceType,
                sourceName: provider.name,
                items: items
            )
        } catch {
            return SourceFetchResult(
                sourceType: provider.sourceType,
                sourceName: provider.name,
                error: error
            )
        }
    }

    private func fetchFromFolderProvider(_ provider: FolderSourceProvider) async -> SourceFetchResult {
        do {
            let items = try await provider.fetchItems()
            let explorations = try await provider.explore(with: explorationEngine)
            return SourceFetchResult(
                sourceType: .folder,
                sourceName: provider.name,
                items: items,
                explorationResults: explorations
            )
        } catch {
            return SourceFetchResult(
                sourceType: .folder,
                sourceName: provider.name,
                error: error
            )
        }
    }
}
