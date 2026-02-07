import XCTest
@testable import WhatsNext

final class PromptBuilderTests: XCTestCase {

    // MARK: - buildAnalysisPrompt Tests

    func testBuildAnalysisPromptIncludesSystemPrompt() {
        let systemPrompt = "You are a test assistant."
        let prompt = PromptBuilder.buildAnalysisPrompt(
            items: [],
            explorations: [],
            systemPrompt: systemPrompt
        )

        XCTAssertTrue(prompt.contains(systemPrompt))
    }

    func testBuildAnalysisPromptIncludesJSONFormatInstructions() {
        let prompt = PromptBuilder.buildAnalysisPrompt(
            items: [],
            explorations: [],
            systemPrompt: "Test"
        )

        XCTAssertTrue(prompt.contains("Respond ONLY with valid JSON"))
        XCTAssertTrue(prompt.contains("\"tasks\""))
        XCTAssertTrue(prompt.contains("\"title\""))
        XCTAssertTrue(prompt.contains("\"priority\""))
        XCTAssertTrue(prompt.contains("\"actionPlan\""))
    }

    func testBuildAnalysisPromptIncludesSourceItems() {
        let items = [
            SourceItem(
                sourceType: .folder,
                sourceName: "TestProject",
                title: "TODO in main.swift",
                content: "Fix memory leak"
            ),
            SourceItem(
                sourceType: .mail,
                sourceName: "Inbox",
                title: "Meeting reminder",
                content: "Don't forget the standup"
            )
        ]

        let prompt = PromptBuilder.buildAnalysisPrompt(
            items: items,
            explorations: [],
            systemPrompt: "Test"
        )

        XCTAssertTrue(prompt.contains("SOURCE ITEMS"))
        XCTAssertTrue(prompt.contains("TODO in main.swift"))
        XCTAssertTrue(prompt.contains("Meeting reminder"))
    }

    func testBuildAnalysisPromptGroupsItemsByType() {
        let items = [
            SourceItem(sourceType: .folder, sourceName: "Project", title: "File 1", content: "content1"),
            SourceItem(sourceType: .folder, sourceName: "Project", title: "File 2", content: "content2"),
            SourceItem(sourceType: .mail, sourceName: "Inbox", title: "Email 1", content: "email content")
        ]

        let prompt = PromptBuilder.buildAnalysisPrompt(
            items: items,
            explorations: [],
            systemPrompt: "Test"
        )

        XCTAssertTrue(prompt.contains("FOLDER"))
        XCTAssertTrue(prompt.contains("MAIL"))
    }

    func testBuildAnalysisPromptIncludesExplorationResults() {
        let exploration = ExplorationResult(
            strategyId: "git-status",
            strategyName: "Git Status",
            sourcePath: URL(fileURLWithPath: "/test/path"),
            findings: [
                ExplorationFinding(
                    findingType: .gitUncommitted,
                    title: "3 uncommitted files",
                    description: "There are uncommitted changes"
                )
            ],
            summary: "Repository has uncommitted changes"
        )

        let prompt = PromptBuilder.buildAnalysisPrompt(
            items: [],
            explorations: [exploration],
            systemPrompt: "Test"
        )

        XCTAssertTrue(prompt.contains("EXPLORATION RESULTS"))
        XCTAssertTrue(prompt.contains("Git Status"))
    }

    func testBuildAnalysisPromptIncludesFeedbackSection() {
        let feedback = "User previously dismissed tasks about documentation."

        let prompt = PromptBuilder.buildAnalysisPrompt(
            items: [],
            explorations: [],
            systemPrompt: "Test",
            feedbackSection: feedback
        )

        XCTAssertTrue(prompt.contains(feedback))
    }

    func testBuildAnalysisPromptWithEmptyInputs() {
        let prompt = PromptBuilder.buildAnalysisPrompt(
            items: [],
            explorations: [],
            systemPrompt: "System prompt here"
        )

        XCTAssertTrue(prompt.contains("System prompt here"))
        XCTAssertFalse(prompt.contains("SOURCE ITEMS"))
        XCTAssertFalse(prompt.contains("EXPLORATION RESULTS"))
    }

    // MARK: - buildExecutionPrompt Tests

    func testBuildExecutionPromptIncludesTaskTitleAndDescription() {
        let task = SuggestedTask(
            title: "Fix login bug",
            description: "The login form crashes on invalid input"
        )

        let prompt = PromptBuilder.buildExecutionPrompt(task: task)

        XCTAssertTrue(prompt.contains("Fix login bug"))
        XCTAssertTrue(prompt.contains("The login form crashes on invalid input"))
        XCTAssertTrue(prompt.contains("Help me complete this task."))
    }

    func testBuildExecutionPromptIncludesActionPlan() {
        let task = SuggestedTask(
            title: "Refactor code",
            description: "Clean up the auth module",
            actionPlan: [
                ActionStep(stepNumber: 1, description: "Extract protocol", command: nil),
                ActionStep(stepNumber: 2, description: "Move implementation", command: "swift build")
            ]
        )

        let prompt = PromptBuilder.buildExecutionPrompt(task: task)

        XCTAssertTrue(prompt.contains("Action Plan:"))
        XCTAssertTrue(prompt.contains("1. Extract protocol"))
        XCTAssertTrue(prompt.contains("2. Move implementation"))
        XCTAssertTrue(prompt.contains("Command: swift build"))
    }

    func testBuildExecutionPromptIncludesSourceInfo() {
        let task = SuggestedTask(
            title: "Fix issue",
            description: "Fix the issue",
            sourceInfo: SourceInfo(
                sourceType: .folder,
                sourceName: "MyProject",
                filePath: "/path/to/file.swift",
                lineNumber: 42
            )
        )

        let prompt = PromptBuilder.buildExecutionPrompt(task: task)

        XCTAssertTrue(prompt.contains("Source: Folder - MyProject"))
        XCTAssertTrue(prompt.contains("File: /path/to/file.swift:42"))
    }

    func testBuildExecutionPromptSourceInfoWithoutLineNumber() {
        let task = SuggestedTask(
            title: "Review",
            description: "Review changes",
            sourceInfo: SourceInfo(
                sourceType: .website,
                sourceName: "Docs",
                filePath: "/path/to/readme.md"
            )
        )

        let prompt = PromptBuilder.buildExecutionPrompt(task: task)

        XCTAssertTrue(prompt.contains("Source: Website - Docs"))
        XCTAssertTrue(prompt.contains("File: /path/to/readme.md"))
        XCTAssertFalse(prompt.contains(":42"))
    }

    func testBuildExecutionPromptWithoutActionPlanOrSourceInfo() {
        let task = SuggestedTask(
            title: "Simple task",
            description: "Just do it"
        )

        let prompt = PromptBuilder.buildExecutionPrompt(task: task)

        XCTAssertTrue(prompt.contains("Simple task"))
        XCTAssertTrue(prompt.contains("Just do it"))
        XCTAssertFalse(prompt.contains("Action Plan:"))
        XCTAssertFalse(prompt.contains("Source:"))
        XCTAssertTrue(prompt.contains("Help me complete this task."))
    }
}
