import Foundation

// MARK: - Task Outcome

enum TaskOutcome: String, Codable {
    case completed
    case dismissed
}

// MARK: - Feedback Record

struct FeedbackRecord: Codable, Identifiable {
    let id: UUID
    var taskTitle: String
    var taskDescription: String
    var sourceType: SourceType
    var sourceName: String
    var sourceIdentifier: String?
    var outcome: TaskOutcome
    var priority: TaskPriority
    var createdAt: Date
    var resolvedAt: Date

    init(
        id: UUID = UUID(),
        taskTitle: String,
        taskDescription: String,
        sourceType: SourceType,
        sourceName: String,
        sourceIdentifier: String? = nil,
        outcome: TaskOutcome,
        priority: TaskPriority,
        createdAt: Date,
        resolvedAt: Date = Date()
    ) {
        self.id = id
        self.taskTitle = taskTitle
        self.taskDescription = taskDescription
        self.sourceType = sourceType
        self.sourceName = sourceName
        self.sourceIdentifier = sourceIdentifier
        self.outcome = outcome
        self.priority = priority
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
    }
}

// MARK: - SuggestedTask → FeedbackRecord

extension SuggestedTask {
    func toFeedbackRecord(outcome: TaskOutcome) -> FeedbackRecord? {
        guard let source = sourceInfo else { return nil }
        return FeedbackRecord(
            taskTitle: title,
            taskDescription: description,
            sourceType: source.sourceType,
            sourceName: source.sourceName,
            sourceIdentifier: source.sourceIdentifier,
            outcome: outcome,
            priority: priority,
            createdAt: createdAt
        )
    }
}
