import Foundation

// MARK: - Prompt Builder

/// Builds prompts for Claude analysis
enum PromptBuilder {

    /// Build the main analysis prompt from source items and explorations
    static func buildAnalysisPrompt(
        items: [SourceItem],
        explorations: [ExplorationResult],
        systemPrompt: String
    ) -> String {
        var prompt = """
        \(systemPrompt)

        IMPORTANT: Respond ONLY with valid JSON in the following format:
        {
          "tasks": [
            {
              "title": "Task title",
              "description": "Why this task is important",
              "priority": "high|medium|low",
              "estimatedMinutes": 30,
              "reasoning": "Brief explanation of why this task was suggested",
              "actionPlan": [
                {"step": 1, "description": "First step", "command": null},
                {"step": 2, "description": "Second step", "command": "optional claude command"}
              ],
              "suggestedCommand": "cd /path && claude 'task description'"
            }
          ]
        }

        Here is the current state of the user's work:

        """

        // Add source items
        if !items.isEmpty {
            prompt += "\n=== SOURCE ITEMS ===\n\n"

            let groupedItems = Dictionary(grouping: items) { $0.sourceType }

            for (sourceType, typeItems) in groupedItems.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                prompt += "--- \(sourceType.displayName.uppercased()) ---\n\n"

                for item in typeItems.prefix(20) {
                    prompt += item.claudeSummary
                    prompt += "\n\n"
                }

                if typeItems.count > 20 {
                    prompt += "... and \(typeItems.count - 20) more items\n\n"
                }
            }
        }

        // Add exploration results
        if !explorations.isEmpty {
            prompt += "\n=== EXPLORATION RESULTS ===\n\n"

            for exploration in explorations {
                prompt += exploration.claudeSummary
                prompt += "\n\n"
            }
        }

        prompt += """

        Based on this information, identify the most important and actionable tasks.

        CRITICAL RULES for task quality:
        - Tasks MUST be specific and concrete, NOT vague or generic.
        - BAD: "Clean up desktop", "Organize files", "Review code"
        - GOOD: "Fix the unhandled nil crash in AuthService.swift:45", "Commit the 3 unstaged files in the WhatsNext repo", "Reply to John's email about the Q3 deadline by tomorrow"
        - Every task title must reference a specific file, project, person, or action.
        - The description must explain exactly WHAT needs to happen and WHERE.
        - The suggestedCommand must be a real, runnable command with the correct working directory and a specific claude prompt describing the exact work.
        - Do NOT suggest tasks that cannot be executed by Claude Code (e.g., "clean your desk", "take a break").
        - Only suggest tasks grounded in the source data provided above. Do not invent tasks.

        Consider:
        1. Time-sensitive items (due dates, meetings) — include the actual date/time
        2. Incomplete work (TODOs, FIXMEs, uncommitted changes) — reference the exact file and line
        3. Unread important emails that need response — include the sender and subject
        4. Quick wins that would reduce mental load — be specific about what and where

        Prioritize tasks that can be acted upon now with Claude Code.
        Respond with JSON only.
        """

        return prompt
    }

    /// Build a prompt for a specific source type analysis
    static func buildSourcePrompt(
        items: [SourceItem],
        sourceType: SourceType,
        additionalContext: String? = nil
    ) -> String {
        var prompt = """
        Analyze the following \(sourceType.displayName.lowercased()) items and identify actionable tasks:

        """

        for item in items.prefix(30) {
            prompt += item.claudeSummary
            prompt += "\n\n"
        }

        if let context = additionalContext {
            prompt += "\nAdditional context: \(context)\n"
        }

        prompt += """

        Respond with JSON containing tasks in this format:
        {
          "tasks": [
            {
              "title": "...",
              "description": "...",
              "priority": "high|medium|low",
              "estimatedMinutes": 30,
              "reasoning": "Brief explanation of why this task was suggested",
              "actionPlan": [{"step": 1, "description": "...", "command": null}],
              "suggestedCommand": "..."
            }
          ]
        }
        """

        return prompt
    }

    /// Build a task execution prompt
    static func buildExecutionPrompt(task: SuggestedTask) -> String {
        var prompt = """
        Task: \(task.title)

        Context: \(task.description)

        """

        if !task.actionPlan.isEmpty {
            prompt += "Action Plan:\n"
            for step in task.actionPlan {
                prompt += "\(step.stepNumber). \(step.description)\n"
                if let command = step.command {
                    prompt += "   Command: \(command)\n"
                }
            }
            prompt += "\n"
        }

        if let sourceInfo = task.sourceInfo {
            prompt += "Source: \(sourceInfo.sourceType.displayName) - \(sourceInfo.sourceName)\n"
            if let filePath = sourceInfo.filePath {
                prompt += "File: \(filePath)"
                if let line = sourceInfo.lineNumber {
                    prompt += ":\(line)"
                }
                prompt += "\n"
            }
        }

        prompt += "\nHelp me complete this task."

        return prompt
    }
}
