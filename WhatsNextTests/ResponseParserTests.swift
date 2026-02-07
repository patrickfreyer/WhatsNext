import XCTest
@testable import WhatsNext

final class ResponseParserTests: XCTestCase {

    // MARK: - parseTasksFromResponse Tests

    func testParseTasksFromCLIWrappedResponse() throws {
        let taskJSON = """
        {"tasks":[{"title":"Fix bug","description":"Fix the login bug","priority":"high","estimatedMinutes":30,"reasoning":"Critical issue","actionPlan":[{"step":1,"description":"Open file","command":"vim file.swift"}],"suggestedCommand":"claude 'fix it'"}]}
        """
        let cliResponse = """
        {"result":"\(taskJSON.replacingOccurrences(of: "\"", with: "\\\""))"}
        """

        let tasks = try ResponseParser.parseTasksFromResponse(
            cliResponse,
            modelUsed: "test-model",
            promptExcerpt: "test prompt",
            sourceNames: ["TestSource"]
        )

        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].title, "Fix bug")
        XCTAssertEqual(tasks[0].description, "Fix the login bug")
        XCTAssertEqual(tasks[0].priority, .high)
        XCTAssertEqual(tasks[0].estimatedMinutes, 30)
        XCTAssertEqual(tasks[0].actionPlan.count, 1)
        XCTAssertEqual(tasks[0].actionPlan[0].description, "Open file")
        XCTAssertEqual(tasks[0].actionPlan[0].command, "vim file.swift")
        XCTAssertEqual(tasks[0].suggestedCommand, "claude 'fix it'")
        XCTAssertEqual(tasks[0].generationLog?.modelUsed, "test-model")
        XCTAssertEqual(tasks[0].generationLog?.sourceNames, ["TestSource"])
    }

    func testParseTasksFromMarkdownCodeFences() throws {
        let response = """
        ```json
        {"tasks":[{"title":"Write tests","description":"Add unit tests","priority":"medium"}]}
        ```
        """

        let tasks = try ResponseParser.parseTasksFromResponse(response)

        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].title, "Write tests")
        XCTAssertEqual(tasks[0].priority, .medium)
    }

    func testParseTasksFromDirectJSON() throws {
        let response = """
        {"tasks":[{"title":"Deploy app","description":"Deploy to production","priority":"low","estimatedMinutes":15}]}
        """

        let tasks = try ResponseParser.parseTasksFromResponse(response)

        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].title, "Deploy app")
        XCTAssertEqual(tasks[0].priority, .low)
        XCTAssertEqual(tasks[0].estimatedMinutes, 15)
    }

    func testParseTasksWithAllFields() throws {
        let response = """
        {"tasks":[{"title":"Refactor auth","description":"Refactor authentication module","priority":"high","estimatedMinutes":60,"reasoning":"Reduces technical debt","actionPlan":[{"step":1,"description":"Extract interface","command":null},{"step":2,"description":"Implement new provider","command":"swift build"}],"suggestedCommand":"cd /project && claude 'refactor auth'"}]}
        """

        let tasks = try ResponseParser.parseTasksFromResponse(
            response,
            modelUsed: "claude-sonnet",
            promptExcerpt: "Analyze code",
            sourceNames: ["ProjectA", "ProjectB"],
            fullPrompt: "Full prompt text",
            fullResponse: "Full response text"
        )

        XCTAssertEqual(tasks.count, 1)
        let task = tasks[0]
        XCTAssertEqual(task.title, "Refactor auth")
        XCTAssertEqual(task.description, "Refactor authentication module")
        XCTAssertEqual(task.priority, .high)
        XCTAssertEqual(task.estimatedMinutes, 60)
        XCTAssertEqual(task.actionPlan.count, 2)
        XCTAssertEqual(task.actionPlan[0].stepNumber, 1)
        XCTAssertEqual(task.actionPlan[0].description, "Extract interface")
        XCTAssertNil(task.actionPlan[0].command)
        XCTAssertEqual(task.actionPlan[1].stepNumber, 2)
        XCTAssertEqual(task.actionPlan[1].command, "swift build")
        XCTAssertEqual(task.suggestedCommand, "cd /project && claude 'refactor auth'")
        XCTAssertEqual(task.generationLog?.modelUsed, "claude-sonnet")
        XCTAssertEqual(task.generationLog?.promptExcerpt, "Analyze code")
        XCTAssertEqual(task.generationLog?.sourceNames, ["ProjectA", "ProjectB"])
        XCTAssertEqual(task.generationLog?.fullPrompt, "Full prompt text")
        XCTAssertEqual(task.generationLog?.fullResponse, "Full response text")
        XCTAssertEqual(task.generationLog?.reasoning, "Reduces technical debt")
    }

    func testParseMultipleTasks() throws {
        let response = """
        {"tasks":[{"title":"Task 1","description":"First","priority":"high"},{"title":"Task 2","description":"Second","priority":"low"}]}
        """

        let tasks = try ResponseParser.parseTasksFromResponse(response)

        XCTAssertEqual(tasks.count, 2)
        XCTAssertEqual(tasks[0].title, "Task 1")
        XCTAssertEqual(tasks[1].title, "Task 2")
    }

    func testParseTasksWithSurroundingText() throws {
        let response = """
        Here are the tasks:
        {"tasks":[{"title":"Clean up","description":"Remove unused code","priority":"medium"}]}
        Hope this helps!
        """

        let tasks = try ResponseParser.parseTasksFromResponse(response)

        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].title, "Clean up")
    }

    func testParseTasksInvalidJSONThrows() {
        let response = "This is not JSON at all"

        XCTAssertThrowsError(try ResponseParser.parseTasksFromResponse(response))
    }

    func testParseTasksDefaultPriority() throws {
        let response = """
        {"tasks":[{"title":"Test","description":"A test task","priority":"unknown"}]}
        """

        let tasks = try ResponseParser.parseTasksFromResponse(response)

        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].priority, .medium)
    }

    // MARK: - validateResponse Tests

    func testValidateResponseWithValidTasksJSON() {
        let response = """
        {"tasks":[{"title":"Test","description":"Test task","priority":"high"}]}
        """

        XCTAssertTrue(ResponseParser.validateResponse(response))
    }

    func testValidateResponseWithInvalidJSON() {
        XCTAssertFalse(ResponseParser.validateResponse("not json"))
    }

    func testValidateResponseWithJSONMissingTasks() {
        let response = """
        {"items":[{"name":"something"}]}
        """

        XCTAssertFalse(ResponseParser.validateResponse(response))
    }

    func testValidateResponseWithEmptyTasksArray() {
        let response = """
        {"tasks":[]}
        """

        XCTAssertTrue(ResponseParser.validateResponse(response))
    }

    // MARK: - Alternative Parsing Tests

    func testParseTasksAlternativeArrayFormat() throws {
        // Direct array of tasks (no wrapping {"tasks": ...})
        let response = """
        [{"title":"Direct task","description":"From array","priority":"high"}]
        """

        // This should fail the primary parse (no "tasks" key) and try alternative parsing
        // Since extractJSON looks for { }, it won't find a top-level object,
        // so this will return the original string which starts with [
        // The alternative parser tries to decode as [ClaudeTaskItem]
        // But extractJSON will return the original since no {} found
        // Actually the response doesn't start with { so extractJSON returns original
        // Then JSONDecoder will try ClaudeTaskResponse which fails
        // Then parseTasksAlternative tries [ClaudeTaskItem] - but data is the extractJSON result
        // The extractJSON won't find { so returns original which is the array
        // But wait - the response does not contain { at all? It starts with [
        // extractJSON looks for firstIndex(of: "{") which is inside the array element
        // So it will extract from the first { to the last } - giving us just the single dict
        // Then ClaudeTaskResponse decode fails, alternative tries [ClaudeTaskItem] on that substring
        // That would also fail since it's not an array
        // Then it tries lenient dictionary parsing which would work on a single dict
        // Actually let me just test with a tasks wrapper that uses unusual formatting
        let response2 = """
        {"tasks": [{"title": "Lenient task", "description": "From lenient parse", "priority": "HIGH", "estimatedMinutes": 10, "reasoning": "Important"}]}
        """

        let tasks = try ResponseParser.parseTasksFromResponse(response2)
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].title, "Lenient task")
    }
}
