import Foundation

// MARK: - Exploration Strategy Protocol

/// Protocol for modular exploration strategies that analyze directories
protocol ExplorationStrategy: AnyObject {
    /// Unique identifier for this strategy
    var id: String { get }

    /// Human-readable name
    var name: String { get }

    /// Description of what this strategy does
    var strategyDescription: String { get }

    /// Check if this strategy can explore the given directory
    func canExplore(at path: URL) async -> Bool

    /// Execute exploration and return findings
    func explore(at path: URL, config: FolderExplorationConfig) async throws -> ExplorationResult
}

// MARK: - Exploration Configuration

struct ExplorationConfig {
    var maxDepth: Int
    var filePatterns: [String]
    var excludePatterns: [String]
    var maxFilesToAnalyze: Int
    var timeoutSeconds: TimeInterval

    init(
        maxDepth: Int = 3,
        filePatterns: [String] = ["*"],
        excludePatterns: [String] = [".git", "node_modules", "build"],
        maxFilesToAnalyze: Int = 50,
        timeoutSeconds: TimeInterval = 30
    ) {
        self.maxDepth = maxDepth
        self.filePatterns = filePatterns
        self.excludePatterns = excludePatterns
        self.maxFilesToAnalyze = maxFilesToAnalyze
        self.timeoutSeconds = timeoutSeconds
    }

    static func from(_ folderConfig: FolderExplorationConfig) -> ExplorationConfig {
        ExplorationConfig(
            maxDepth: folderConfig.maxDepth,
            filePatterns: folderConfig.filePatterns,
            excludePatterns: folderConfig.excludePatterns,
            maxFilesToAnalyze: folderConfig.maxFilesToAnalyze
        )
    }
}

// MARK: - Exploration Strategy Error

enum ExplorationStrategyError: Error, LocalizedError {
    case pathNotFound(String)
    case notADirectory(String)
    case permissionDenied(String)
    case timeout
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .notADirectory(let path):
            return "Not a directory: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .timeout:
            return "Exploration timed out"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        }
    }
}

// MARK: - Strategy Registry

/// Registry of available exploration strategies
final class ExplorationStrategyRegistry {
    static let shared = ExplorationStrategyRegistry()

    private var strategies: [String: ExplorationStrategy] = [:]

    private init() {
        // Register default strategies
        register(GitStatusStrategy())
        register(TodoScannerStrategy())
        register(RecentChangesStrategy())
        register(ProjectStructureStrategy())
    }

    func register(_ strategy: ExplorationStrategy) {
        strategies[strategy.id] = strategy
    }

    func unregister(id: String) {
        strategies.removeValue(forKey: id)
    }

    func strategy(for id: String) -> ExplorationStrategy? {
        strategies[id]
    }

    func allStrategies() -> [ExplorationStrategy] {
        Array(strategies.values)
    }

    func enabledStrategies(ids: [String]) -> [ExplorationStrategy] {
        ids.compactMap { strategies[$0] }
    }
}
