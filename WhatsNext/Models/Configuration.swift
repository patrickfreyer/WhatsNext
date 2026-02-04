import Foundation

// MARK: - Root Configuration

struct AppConfiguration: Codable {
    var general: GeneralConfiguration
    var claude: ClaudeConfiguration
    var sources: SourcesConfiguration

    static var `default`: AppConfiguration {
        AppConfiguration(
            general: .default,
            claude: .default,
            sources: .default
        )
    }
}

// MARK: - General Configuration

struct GeneralConfiguration: Codable {
    var launchAtLogin: Bool
    var refreshIntervalMinutes: Int
    var maxTasksToShow: Int

    static var `default`: GeneralConfiguration {
        GeneralConfiguration(
            launchAtLogin: false,
            refreshIntervalMinutes: 30,
            maxTasksToShow: 5
        )
    }
}

// MARK: - Claude Configuration

struct ClaudeConfiguration: Codable {
    var systemPrompt: String
    var modelName: String
    var maxTokens: Int

    static var `default`: ClaudeConfiguration {
        ClaudeConfiguration(
            systemPrompt: """
                You are a productivity assistant analyzing the user's projects, emails, reminders, and bookmarked websites.
                Your job is to identify actionable tasks and prioritize them based on urgency and importance.

                For each task you suggest:
                1. Provide a clear, concise title
                2. Explain why this task is important
                3. Estimate time needed
                4. Provide step-by-step action plan
                5. Include a Claude Code command that can help complete the task

                Focus on tasks that are:
                - Time-sensitive (deadlines, meetings)
                - Blocking other work
                - Quick wins that reduce mental load
                - Important but being procrastinated
                """,
            modelName: "claude-sonnet-4-20250514",
            maxTokens: 4096
        )
    }
}

// MARK: - Sources Configuration

struct SourcesConfiguration: Codable {
    var folders: [FolderSourceConfiguration]
    var websites: [WebsiteSourceConfiguration]
    var reminders: RemindersSourceConfiguration
    var mail: MailSourceConfiguration

    static var `default`: SourcesConfiguration {
        SourcesConfiguration(
            folders: [],
            websites: [],
            reminders: .default,
            mail: .default
        )
    }
}

// MARK: - Folder Source Configuration

struct FolderSourceConfiguration: Codable, Identifiable {
    var id: UUID
    var name: String
    var path: String
    var isEnabled: Bool
    var exploration: FolderExplorationConfig

    init(id: UUID = UUID(), name: String, path: String, isEnabled: Bool = true, exploration: FolderExplorationConfig = .default) {
        self.id = id
        self.name = name
        self.path = path
        self.isEnabled = isEnabled
        self.exploration = exploration
    }
}

struct FolderExplorationConfig: Codable {
    var enabledStrategies: [String]
    var maxDepth: Int
    var filePatterns: [String]
    var excludePatterns: [String]
    var maxFilesToAnalyze: Int

    static var `default`: FolderExplorationConfig {
        FolderExplorationConfig(
            enabledStrategies: ["git-status", "todo-scanner", "recent-changes"],
            maxDepth: 3,
            filePatterns: ["*.swift", "*.md", "*.txt", "*.json"],
            excludePatterns: [".git", "node_modules", "build", ".build", "DerivedData", "Pods"],
            maxFilesToAnalyze: 50
        )
    }
}

// MARK: - Website Source Configuration

struct WebsiteSourceConfiguration: Codable, Identifiable {
    var id: UUID
    var name: String
    var url: String
    var isEnabled: Bool
    var refreshIntervalMinutes: Int?

    init(id: UUID = UUID(), name: String, url: String, isEnabled: Bool = true, refreshIntervalMinutes: Int? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
        self.refreshIntervalMinutes = refreshIntervalMinutes
    }
}

// MARK: - Reminders Source Configuration

struct RemindersSourceConfiguration: Codable {
    var isEnabled: Bool
    var listNames: [String]?
    var includeCompleted: Bool

    static var `default`: RemindersSourceConfiguration {
        RemindersSourceConfiguration(
            isEnabled: true,
            listNames: nil,
            includeCompleted: false
        )
    }
}

// MARK: - Mail Source Configuration

struct MailSourceConfiguration: Codable {
    var isEnabled: Bool
    var mailboxNames: [String]
    var maxEmailsToFetch: Int
    var onlyUnread: Bool
    var onlyFlagged: Bool

    static var `default`: MailSourceConfiguration {
        MailSourceConfiguration(
            isEnabled: true,
            mailboxNames: ["INBOX"],
            maxEmailsToFetch: 20,
            onlyUnread: true,
            onlyFlagged: false
        )
    }
}

// MARK: - Protocol for Source Configurations

protocol SourceProviderConfiguration: Codable, Identifiable {
    var isEnabled: Bool { get set }
}

extension FolderSourceConfiguration: SourceProviderConfiguration {}
extension WebsiteSourceConfiguration: SourceProviderConfiguration {}
