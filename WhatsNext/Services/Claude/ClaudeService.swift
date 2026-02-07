import Foundation

// MARK: - Claude Service

/// Service for interacting with Claude CLI
final class ClaudeService {
    static let shared = ClaudeService()

    private let processQueue = DispatchQueue(label: "com.whatsnext.claude", qos: .userInitiated)

    /// JSON schema for structured task output, enforced by --json-schema
    static let taskResponseSchema: String = """
    {"type":"object","properties":{"tasks":{"type":"array","items":{"type":"object","properties":{"title":{"type":"string"},"description":{"type":"string"},"priority":{"type":"string","enum":["high","medium","low"]},"estimatedMinutes":{"type":"integer"},"reasoning":{"type":"string"},"actionPlan":{"type":"array","items":{"type":"object","properties":{"step":{"type":"integer"},"description":{"type":"string"},"command":{"type":["string","null"]}},"required":["step","description"]}},"suggestedCommand":{"type":["string","null"]},"sourceType":{"type":"string","enum":["folder","website","reminders","mail","calendar"]},"sourceName":{"type":"string"}},"required":["title","description","priority","reasoning","actionPlan"]}}},"required":["tasks"]}
    """

    private init() {}

    // MARK: - Public Methods

    /// Execute Claude CLI with the given prompt and return the response
    func executePrompt(_ prompt: String, config: ClaudeConfiguration) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            processQueue.async {
                do {
                    let result = try self.runClaudeCLI(prompt: prompt, config: config)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Analyze sources and return suggested tasks
    func analyzeSources(
        items: [SourceItem],
        explorations: [ExplorationResult],
        config: ClaudeConfiguration,
        feedbackSection: String? = nil
    ) async throws -> [SuggestedTask] {
        debugLog("[WhatsNext] Analyzing \(items.count) items and \(explorations.count) explorations")

        let prompt = PromptBuilder.buildAnalysisPrompt(
            items: items,
            explorations: explorations,
            systemPrompt: config.systemPrompt,
            feedbackSection: feedbackSection
        )

        debugLog("[WhatsNext] Prompt length: \(prompt.count) characters")

        let response = try await executePrompt(prompt, config: config)
        debugLog("[WhatsNext] Response length: \(response.count) characters")
        debugLog("[WhatsNext] Response preview: \(String(response.prefix(500)))")

        let promptExcerpt = String(prompt.prefix(200))
        let sourceNames = Array(Set(items.map { $0.sourceName })).sorted()

        // Try structured_output first (from --json-schema), fall back to result field
        let tasks = try ResponseParser.parseTasksFromCLIResponse(
            response,
            modelUsed: config.modelName,
            promptExcerpt: promptExcerpt,
            sourceNames: sourceNames,
            fullPrompt: prompt,
            fullResponse: response
        )
        debugLog("[WhatsNext] Parsed \(tasks.count) tasks")

        return tasks
    }

    // MARK: - Private Methods

    private func findClaudeCLI() -> URL? {
        let possiblePaths = [
            "\(NSHomeDirectory())/.local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/bin/claude"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private func runClaudeCLI(prompt: String, config: ClaudeConfiguration) throws -> String {
        guard let claudePath = findClaudeCLI() else {
            throw ClaudeServiceError.cliNotFound
        }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = claudePath

        // Map model name to Claude CLI alias
        let modelAlias: String
        if config.modelName.contains("opus") {
            modelAlias = "opus"
        } else if config.modelName.contains("haiku") {
            modelAlias = "haiku"
        } else {
            modelAlias = "sonnet"
        }

        let toolsList = config.explorationTools.joined(separator: ",")
        let budgetString = String(format: "%.2f", config.maxBudgetUSD)

        process.arguments = [
            "--print",
            "--output-format", "json",
            "--model", modelAlias,
            "--json-schema", Self.taskResponseSchema,
            "--tools", toolsList,
            "--max-budget-usd", budgetString,
            prompt
        ]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ClaudeServiceError.cliNotFound
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ClaudeServiceError.executionFailed(errorMessage)
        }

        guard let output = String(data: outputData, encoding: .utf8) else {
            throw ClaudeServiceError.invalidResponse
        }

        return output
    }
}

// MARK: - Claude Service Error

enum ClaudeServiceError: Error, LocalizedError {
    case cliNotFound
    case executionFailed(String)
    case invalidResponse
    case parsingFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .cliNotFound:
            return "Claude CLI not found. Please ensure 'claude' is installed and in PATH."
        case .executionFailed(let message):
            return "Claude CLI execution failed: \(message)"
        case .invalidResponse:
            return "Invalid response from Claude CLI"
        case .parsingFailed(let message):
            return "Failed to parse Claude response: \(message)"
        case .timeout:
            return "Claude CLI request timed out"
        }
    }
}
