import Foundation

// MARK: - Source Provider Protocol

/// Protocol for all data source providers (folders, websites, reminders, mail)
protocol SourceProvider: AnyObject {
    /// Unique identifier for this provider instance
    var id: UUID { get }

    /// Human-readable name for this source
    var name: String { get }

    /// Type of source this provider handles
    var sourceType: SourceType { get }

    /// Whether this provider is currently enabled
    var isEnabled: Bool { get set }

    /// Fetch items from this source
    func fetchItems() async throws -> [SourceItem]

    /// Validate the provider's configuration
    func validateConfiguration() -> Bool

    /// Check if the app has necessary permissions
    func checkPermissions() async -> Bool

    /// Request permissions if not already granted
    func requestPermissions() async throws
}

// MARK: - Source Provider Error

enum SourceProviderError: Error, LocalizedError {
    case configurationInvalid(String)
    case permissionDenied(String)
    case fetchFailed(String)
    case notAvailable(String)
    case timeout
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .configurationInvalid(let message):
            return "Invalid configuration: \(message)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch: \(message)"
        case .notAvailable(let message):
            return "Not available: \(message)"
        case .timeout:
            return "Operation timed out"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Explorable Source Provider

/// Extension protocol for sources that support exploration (e.g., folders)
protocol ExplorableSourceProvider: SourceProvider {
    /// Run exploration strategies on this source
    func explore(with engine: ExplorationEngine) async throws -> [ExplorationResult]
}

// MARK: - Source Provider Factory

/// Factory for creating source providers
enum SourceProviderFactory {
    static func createFolderProvider(config: FolderSourceConfiguration) -> FolderSourceProvider {
        FolderSourceProvider(configuration: config)
    }

    static func createWebsiteProvider(config: WebsiteSourceConfiguration) -> WebsiteSourceProvider {
        WebsiteSourceProvider(configuration: config)
    }

    static func createRemindersProvider(config: RemindersSourceConfiguration) -> RemindersSourceProvider {
        RemindersSourceProvider(configuration: config)
    }

    static func createMailProvider(config: MailSourceConfiguration) -> MailSourceProvider {
        MailSourceProvider(configuration: config)
    }
}
