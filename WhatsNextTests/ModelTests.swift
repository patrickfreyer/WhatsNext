import XCTest
@testable import WhatsNext

final class ModelTests: XCTestCase {

    // MARK: - SuggestedTask Tests

    func testSuggestedTaskCreationWithDefaults() {
        let task = SuggestedTask(title: "Test Task", description: "A test task")

        XCTAssertEqual(task.title, "Test Task")
        XCTAssertEqual(task.description, "A test task")
        XCTAssertEqual(task.priority, .medium)
        XCTAssertNil(task.estimatedMinutes)
        XCTAssertTrue(task.actionPlan.isEmpty)
        XCTAssertNil(task.suggestedCommand)
        XCTAssertNil(task.sourceInfo)
        XCTAssertEqual(task.status, .pending)
        XCTAssertNil(task.generationLog)
    }

    func testSuggestedTaskCreationWithAllFields() {
        let sourceInfo = SourceInfo(
            sourceType: .folder,
            sourceName: "MyProject",
            sourceIdentifier: "proj-1",
            filePath: "/path/to/file.swift",
            lineNumber: 42
        )
        let log = GenerationLog(
            generatedAt: Date(),
            sourceNames: ["Source1"],
            reasoning: "Important",
            modelUsed: "claude",
            promptExcerpt: "analyze",
            fullPrompt: nil,
            fullResponse: nil
        )
        let step = ActionStep(stepNumber: 1, description: "Do something", command: "echo hi")

        let task = SuggestedTask(
            title: "Full Task",
            description: "Complete task",
            priority: .high,
            estimatedMinutes: 45,
            actionPlan: [step],
            suggestedCommand: "claude 'do it'",
            sourceInfo: sourceInfo,
            status: .inProgress,
            generationLog: log
        )

        XCTAssertEqual(task.title, "Full Task")
        XCTAssertEqual(task.priority, .high)
        XCTAssertEqual(task.estimatedMinutes, 45)
        XCTAssertEqual(task.actionPlan.count, 1)
        XCTAssertEqual(task.suggestedCommand, "claude 'do it'")
        XCTAssertEqual(task.sourceInfo?.sourceName, "MyProject")
        XCTAssertEqual(task.status, .inProgress)
        XCTAssertNotNil(task.generationLog)
    }

    func testSuggestedTaskNormalizedTitle() {
        let task = SuggestedTask(title: "  Fix The Bug  ", description: "desc")
        XCTAssertEqual(task.normalizedTitle, "fix the bug")
    }

    func testSuggestedTaskNormalizedTitleAlreadyLowercase() {
        let task = SuggestedTask(title: "already lowercase", description: "desc")
        XCTAssertEqual(task.normalizedTitle, "already lowercase")
    }

    func testSuggestedTaskIdentifiable() {
        let task1 = SuggestedTask(title: "Task 1", description: "desc")
        let task2 = SuggestedTask(title: "Task 2", description: "desc")
        XCTAssertNotEqual(task1.id, task2.id)
    }

    // MARK: - TaskPriority Tests

    func testTaskPrioritySortOrder() {
        XCTAssertEqual(TaskPriority.high.sortOrder, 0)
        XCTAssertEqual(TaskPriority.medium.sortOrder, 1)
        XCTAssertEqual(TaskPriority.low.sortOrder, 2)
    }

    func testTaskPriorityDisplayName() {
        XCTAssertEqual(TaskPriority.high.displayName, "High")
        XCTAssertEqual(TaskPriority.medium.displayName, "Medium")
        XCTAssertEqual(TaskPriority.low.displayName, "Low")
    }

    func testTaskPriorityRawValue() {
        XCTAssertEqual(TaskPriority(rawValue: "high"), .high)
        XCTAssertEqual(TaskPriority(rawValue: "medium"), .medium)
        XCTAssertEqual(TaskPriority(rawValue: "low"), .low)
        XCTAssertNil(TaskPriority(rawValue: "invalid"))
    }

    func testTaskPriorityColor() {
        XCTAssertEqual(TaskPriority.high.color, "red")
        XCTAssertEqual(TaskPriority.medium.color, "orange")
        XCTAssertEqual(TaskPriority.low.color, "blue")
    }

    // MARK: - TaskStatus Tests

    func testTaskStatusSortOrder() {
        XCTAssertEqual(TaskStatus.inProgress.sortOrder, 0)
        XCTAssertEqual(TaskStatus.pending.sortOrder, 1)
        XCTAssertEqual(TaskStatus.completed.sortOrder, 2)
        XCTAssertEqual(TaskStatus.dismissed.sortOrder, 3)
    }

    func testTaskStatusDisplayName() {
        XCTAssertEqual(TaskStatus.pending.displayName, "Pending")
        XCTAssertEqual(TaskStatus.inProgress.displayName, "In Progress")
        XCTAssertEqual(TaskStatus.completed.displayName, "Completed")
        XCTAssertEqual(TaskStatus.dismissed.displayName, "Dismissed")
    }

    func testTaskStatusRawValue() {
        XCTAssertEqual(TaskStatus(rawValue: "pending"), .pending)
        XCTAssertEqual(TaskStatus(rawValue: "inProgress"), .inProgress)
        XCTAssertEqual(TaskStatus(rawValue: "completed"), .completed)
        XCTAssertEqual(TaskStatus(rawValue: "dismissed"), .dismissed)
        XCTAssertNil(TaskStatus(rawValue: "invalid"))
    }

    // MARK: - ActionStep Tests

    func testActionStepCreation() {
        let step = ActionStep(stepNumber: 1, description: "Run tests", command: "swift test")

        XCTAssertEqual(step.stepNumber, 1)
        XCTAssertEqual(step.description, "Run tests")
        XCTAssertEqual(step.command, "swift test")
    }

    func testActionStepWithoutCommand() {
        let step = ActionStep(stepNumber: 2, description: "Review code")

        XCTAssertEqual(step.stepNumber, 2)
        XCTAssertEqual(step.description, "Review code")
        XCTAssertNil(step.command)
    }

    func testActionStepIdentifiable() {
        let step1 = ActionStep(stepNumber: 1, description: "Step 1")
        let step2 = ActionStep(stepNumber: 2, description: "Step 2")
        XCTAssertNotEqual(step1.id, step2.id)
    }

    // MARK: - SourceInfo Tests

    func testSourceInfoCreation() {
        let info = SourceInfo(
            sourceType: .folder,
            sourceName: "Projects",
            sourceIdentifier: "proj-id",
            filePath: "/Users/test/project",
            lineNumber: 10
        )

        XCTAssertEqual(info.sourceType, .folder)
        XCTAssertEqual(info.sourceName, "Projects")
        XCTAssertEqual(info.sourceIdentifier, "proj-id")
        XCTAssertEqual(info.filePath, "/Users/test/project")
        XCTAssertEqual(info.lineNumber, 10)
    }

    func testSourceInfoMinimalCreation() {
        let info = SourceInfo(sourceType: .mail, sourceName: "Inbox")

        XCTAssertEqual(info.sourceType, .mail)
        XCTAssertEqual(info.sourceName, "Inbox")
        XCTAssertNil(info.sourceIdentifier)
        XCTAssertNil(info.filePath)
        XCTAssertNil(info.lineNumber)
    }

    // MARK: - SourceType Tests

    func testSourceTypeDisplayName() {
        XCTAssertEqual(SourceType.folder.displayName, "Folder")
        XCTAssertEqual(SourceType.website.displayName, "Website")
        XCTAssertEqual(SourceType.reminders.displayName, "Reminders")
        XCTAssertEqual(SourceType.mail.displayName, "Mail")
    }

    func testSourceTypeIconName() {
        XCTAssertEqual(SourceType.folder.iconName, "folder")
        XCTAssertEqual(SourceType.website.iconName, "globe")
        XCTAssertEqual(SourceType.reminders.iconName, "checklist")
        XCTAssertEqual(SourceType.mail.iconName, "envelope")
    }

    // MARK: - ClaudeTaskItem Tests

    func testClaudeTaskItemToSuggestedTask() {
        let item = ClaudeTaskItem(
            title: "Test Task",
            description: "A task from Claude",
            priority: "High",
            estimatedMinutes: 20,
            actionPlan: [
                ClaudeActionStep(step: 1, description: "First step", command: "echo hello"),
                ClaudeActionStep(step: 2, description: "Second step", command: nil)
            ],
            suggestedCommand: "claude 'do something'",
            reasoning: "Because it matters"
        )

        let task = item.toSuggestedTask(
            modelUsed: "test-model",
            promptExcerpt: "test prompt",
            sourceNames: ["Source1"]
        )

        XCTAssertEqual(task.title, "Test Task")
        XCTAssertEqual(task.description, "A task from Claude")
        XCTAssertEqual(task.priority, .high)
        XCTAssertEqual(task.estimatedMinutes, 20)
        XCTAssertEqual(task.actionPlan.count, 2)
        XCTAssertEqual(task.actionPlan[0].stepNumber, 1)
        XCTAssertEqual(task.actionPlan[0].description, "First step")
        XCTAssertEqual(task.actionPlan[0].command, "echo hello")
        XCTAssertEqual(task.actionPlan[1].stepNumber, 2)
        XCTAssertNil(task.actionPlan[1].command)
        XCTAssertEqual(task.suggestedCommand, "claude 'do something'")
        XCTAssertEqual(task.status, .pending)
        XCTAssertEqual(task.generationLog?.modelUsed, "test-model")
        XCTAssertEqual(task.generationLog?.reasoning, "Because it matters")
    }

    func testClaudeTaskItemToSuggestedTaskUnknownPriority() {
        let item = ClaudeTaskItem(
            title: "Test",
            description: "Desc",
            priority: "CRITICAL",
            estimatedMinutes: nil,
            actionPlan: nil,
            suggestedCommand: nil,
            reasoning: nil
        )

        let task = item.toSuggestedTask()

        XCTAssertEqual(task.priority, .medium)
        XCTAssertTrue(task.actionPlan.isEmpty)
        XCTAssertNil(task.estimatedMinutes)
    }

    // MARK: - Configuration Tests

    func testAppConfigurationDefault() {
        let config = AppConfiguration.default

        XCTAssertFalse(config.general.launchAtLogin)
        XCTAssertEqual(config.general.refreshIntervalMinutes, 30)
        XCTAssertEqual(config.general.maxTasksToShow, 5)
    }

    func testGeneralConfigurationDefault() {
        let config = GeneralConfiguration.default

        XCTAssertFalse(config.launchAtLogin)
        XCTAssertEqual(config.refreshIntervalMinutes, 30)
        XCTAssertEqual(config.maxTasksToShow, 5)
    }

    func testClaudeConfigurationDefault() {
        let config = ClaudeConfiguration.default

        XCTAssertFalse(config.systemPrompt.isEmpty)
        XCTAssertEqual(config.modelName, "claude-sonnet-4-20250514")
        XCTAssertEqual(config.maxTokens, 4096)
    }

    // MARK: - GenerationLog Tests

    func testGenerationLogCreation() {
        let date = Date()
        let log = GenerationLog(
            generatedAt: date,
            sourceNames: ["A", "B"],
            reasoning: "Test reasoning",
            modelUsed: "claude-opus",
            promptExcerpt: "test",
            fullPrompt: "full prompt",
            fullResponse: "full response"
        )

        XCTAssertEqual(log.generatedAt, date)
        XCTAssertEqual(log.sourceNames, ["A", "B"])
        XCTAssertEqual(log.reasoning, "Test reasoning")
        XCTAssertEqual(log.modelUsed, "claude-opus")
        XCTAssertEqual(log.promptExcerpt, "test")
        XCTAssertEqual(log.fullPrompt, "full prompt")
        XCTAssertEqual(log.fullResponse, "full response")
    }
}
