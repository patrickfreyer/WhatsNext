import Foundation

// MARK: - Response Parser

/// Parses Claude CLI responses into structured data
enum ResponseParser {

    /// Parse tasks from Claude's JSON response
    static func parseTasksFromResponse(
        _ response: String,
        modelUsed: String = "",
        promptExcerpt: String = "",
        sourceNames: [String] = [],
        fullPrompt: String? = nil,
        fullResponse: String? = nil
    ) throws -> [SuggestedTask] {
        // Step 1: Extract the actual result from Claude CLI wrapper
        let actualResult = extractResultFromCLIResponse(response)

        // Step 2: Remove markdown code fences if present
        let cleanedResult = removeMarkdownCodeFences(from: actualResult)

        // Step 3: Extract JSON from the cleaned result
        let jsonString = extractJSON(from: cleanedResult)

        guard let data = jsonString.data(using: .utf8) else {
            throw ClaudeServiceError.parsingFailed("Could not convert response to data")
        }

        do {
            let decoder = JSONDecoder()
            let taskResponse = try decoder.decode(ClaudeTaskResponse.self, from: data)
            return taskResponse.tasks.map {
                $0.toSuggestedTask(
                    modelUsed: modelUsed,
                    promptExcerpt: promptExcerpt,
                    sourceNames: sourceNames,
                    fullPrompt: fullPrompt,
                    fullResponse: fullResponse
                )
            }
        } catch {
            // Try alternative parsing
            return try parseTasksAlternative(
                from: jsonString,
                modelUsed: modelUsed,
                promptExcerpt: promptExcerpt,
                sourceNames: sourceNames,
                fullPrompt: fullPrompt,
                fullResponse: fullResponse
            )
        }
    }

    /// Extract the 'result' field from Claude CLI JSON wrapper response
    private static func extractResultFromCLIResponse(_ response: String) -> String {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? String else {
            // Not a CLI wrapper, return as-is
            return response
        }
        return result
    }

    /// Remove markdown code fences (```json ... ```)
    private static func removeMarkdownCodeFences(from text: String) -> String {
        var result = text

        // Remove ```json or ``` at the start
        if result.hasPrefix("```json") {
            result = String(result.dropFirst(7))
        } else if result.hasPrefix("```") {
            result = String(result.dropFirst(3))
        }

        // Remove ``` at the end
        if result.hasSuffix("```") {
            result = String(result.dropLast(3))
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract JSON from a response that might have other text
    private static func extractJSON(from response: String) -> String {
        // Look for JSON object
        if let startIndex = response.firstIndex(of: "{"),
           let endIndex = response.lastIndex(of: "}") {
            return String(response[startIndex...endIndex])
        }

        // If no JSON found, return original (will fail parsing with clear error)
        return response
    }

    /// Alternative parsing for malformed responses
    private static func parseTasksAlternative(
        from jsonString: String,
        modelUsed: String = "",
        promptExcerpt: String = "",
        sourceNames: [String] = []
    ) throws -> [SuggestedTask] {
        // Try to parse as array of tasks directly
        guard let data = jsonString.data(using: .utf8) else {
            throw ClaudeServiceError.parsingFailed("Could not convert to data")
        }

        // Try parsing as tasks array
        if let tasksArray = try? JSONDecoder().decode([ClaudeTaskItem].self, from: data) {
            return tasksArray.map {
                $0.toSuggestedTask(
                    modelUsed: modelUsed,
                    promptExcerpt: promptExcerpt,
                    sourceNames: sourceNames
                )
            }
        }

        // Try parsing with a more lenient approach
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let tasksArray = json["tasks"] as? [[String: Any]] {
            return tasksArray.compactMap {
                parseTaskFromDictionary(
                    $0,
                    modelUsed: modelUsed,
                    promptExcerpt: promptExcerpt,
                    sourceNames: sourceNames
                )
            }
        }

        throw ClaudeServiceError.parsingFailed("Could not parse response as tasks")
    }

    /// Parse a single task from a dictionary (for lenient parsing)
    private static func parseTaskFromDictionary(
        _ dict: [String: Any],
        modelUsed: String = "",
        promptExcerpt: String = "",
        sourceNames: [String] = []
    ) -> SuggestedTask? {
        guard let title = dict["title"] as? String,
              let description = dict["description"] as? String else {
            return nil
        }

        let priorityString = dict["priority"] as? String ?? "medium"
        let priority = TaskPriority(rawValue: priorityString.lowercased()) ?? .medium

        let estimatedMinutes = dict["estimatedMinutes"] as? Int
        let reasoning = dict["reasoning"] as? String

        var actionPlan: [ActionStep] = []
        if let actionPlanArray = dict["actionPlan"] as? [[String: Any]] {
            actionPlan = actionPlanArray.enumerated().compactMap { index, stepDict in
                guard let stepDescription = stepDict["description"] as? String else { return nil }
                let command = stepDict["command"] as? String
                return ActionStep(stepNumber: index + 1, description: stepDescription, command: command)
            }
        }

        let suggestedCommand = dict["suggestedCommand"] as? String

        let log = GenerationLog(
            generatedAt: Date(),
            sourceNames: sourceNames,
            reasoning: reasoning ?? "",
            modelUsed: modelUsed,
            promptExcerpt: promptExcerpt
        )

        return SuggestedTask(
            title: title,
            description: description,
            priority: priority,
            estimatedMinutes: estimatedMinutes,
            actionPlan: actionPlan,
            suggestedCommand: suggestedCommand,
            generationLog: log
        )
    }

    /// Validate that a response contains valid task JSON
    static func validateResponse(_ response: String) -> Bool {
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8) else {
            return false
        }

        // Check if it's valid JSON with tasks
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["tasks"] != nil {
            return true
        }

        return false
    }
}
