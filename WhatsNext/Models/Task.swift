import Foundation

// MARK: - Task Status

enum TaskStatus: String, Codable, CaseIterable {
    case pending
    case inProgress
    case completed
    case dismissed

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .dismissed: return "Dismissed"
        }
    }

    var sortOrder: Int {
        switch self {
        case .inProgress: return 0
        case .pending: return 1
        case .completed: return 2
        case .dismissed: return 3
        }
    }
}

// MARK: - Generation Log

struct GenerationLog: Codable {
    var generatedAt: Date
    var sourceNames: [String]
    var reasoning: String
    var modelUsed: String
    var promptExcerpt: String
    var fullPrompt: String?
    var fullResponse: String?
}

// MARK: - Suggested Task

struct SuggestedTask: Codable, Identifiable {
    let id: UUID
    var title: String
    var description: String
    var priority: TaskPriority
    var estimatedMinutes: Int?
    var actionPlan: [ActionStep]
    var suggestedCommand: String?
    var sourceInfo: SourceInfo?
    var status: TaskStatus
    var createdAt: Date
    var updatedAt: Date
    var generationLog: GenerationLog?

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        priority: TaskPriority = .medium,
        estimatedMinutes: Int? = nil,
        actionPlan: [ActionStep] = [],
        suggestedCommand: String? = nil,
        sourceInfo: SourceInfo? = nil,
        status: TaskStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        generationLog: GenerationLog? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
        self.estimatedMinutes = estimatedMinutes
        self.actionPlan = actionPlan
        self.suggestedCommand = suggestedCommand
        self.sourceInfo = sourceInfo
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.generationLog = generationLog
    }

    /// Normalized title for matching tasks across refreshes
    var normalizedTitle: String {
        title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Task Priority

enum TaskPriority: String, Codable, CaseIterable {
    case high
    case medium
    case low

    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    var color: String {
        switch self {
        case .high: return "red"
        case .medium: return "orange"
        case .low: return "blue"
        }
    }

    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

// MARK: - Action Step

struct ActionStep: Codable, Identifiable {
    let id: UUID
    var stepNumber: Int
    var description: String
    var command: String?

    init(id: UUID = UUID(), stepNumber: Int, description: String, command: String? = nil) {
        self.id = id
        self.stepNumber = stepNumber
        self.description = description
        self.command = command
    }
}

// MARK: - Source Info

struct SourceInfo: Codable {
    var sourceType: SourceType
    var sourceName: String
    var sourceIdentifier: String?
    var filePath: String?
    var lineNumber: Int?

    init(sourceType: SourceType, sourceName: String, sourceIdentifier: String? = nil, filePath: String? = nil, lineNumber: Int? = nil) {
        self.sourceType = sourceType
        self.sourceName = sourceName
        self.sourceIdentifier = sourceIdentifier
        self.filePath = filePath
        self.lineNumber = lineNumber
    }
}

// MARK: - Source Type

enum SourceType: String, Codable, CaseIterable {
    case folder
    case website
    case reminders
    case mail
    case calendar

    var displayName: String {
        switch self {
        case .folder: return "Folder"
        case .website: return "Website"
        case .reminders: return "Reminders"
        case .mail: return "Mail"
        case .calendar: return "Calendar"
        }
    }

    var iconName: String {
        switch self {
        case .folder: return "folder"
        case .website: return "globe"
        case .reminders: return "checklist"
        case .mail: return "envelope"
        case .calendar: return "calendar"
        }
    }
}

// MARK: - Claude Response Models

struct ClaudeTaskResponse: Codable {
    var tasks: [ClaudeTaskItem]
}

struct ClaudeTaskItem: Codable {
    var title: String
    var description: String
    var priority: String
    var estimatedMinutes: Int?
    var actionPlan: [ClaudeActionStep]?
    var suggestedCommand: String?
    var reasoning: String?
    var sourceType: String?
    var sourceName: String?

    func toSuggestedTask(
        sourceInfo: SourceInfo? = nil,
        modelUsed: String = "",
        promptExcerpt: String = "",
        sourceNames: [String] = [],
        fullPrompt: String? = nil,
        fullResponse: String? = nil
    ) -> SuggestedTask {
        let log = GenerationLog(
            generatedAt: Date(),
            sourceNames: sourceNames,
            reasoning: reasoning ?? "",
            modelUsed: modelUsed,
            promptExcerpt: promptExcerpt,
            fullPrompt: fullPrompt,
            fullResponse: fullResponse
        )

        // Build SourceInfo from structured output fields, or use passed-in sourceInfo
        let resolvedSourceInfo: SourceInfo?
        if let sourceInfo = sourceInfo {
            resolvedSourceInfo = sourceInfo
        } else if let typeStr = sourceType, let type = SourceType(rawValue: typeStr) {
            resolvedSourceInfo = SourceInfo(
                sourceType: type,
                sourceName: sourceName ?? "Unknown"
            )
        } else {
            resolvedSourceInfo = nil
        }

        return SuggestedTask(
            title: title,
            description: description,
            priority: TaskPriority(rawValue: priority.lowercased()) ?? .medium,
            estimatedMinutes: estimatedMinutes,
            actionPlan: actionPlan?.enumerated().map { index, step in
                ActionStep(stepNumber: index + 1, description: step.description, command: step.command)
            } ?? [],
            suggestedCommand: suggestedCommand,
            sourceInfo: resolvedSourceInfo,
            generationLog: log
        )
    }
}

struct ClaudeActionStep: Codable {
    var step: Int?
    var description: String
    var command: String?
}
