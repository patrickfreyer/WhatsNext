import AppKit
import Foundation

// MARK: - Claude Session Launcher

/// Launches Claude Code sessions for task execution
final class ClaudeSessionLauncher {
    static let shared = ClaudeSessionLauncher()

    private init() {}

    // MARK: - Public Methods

    /// Execute a suggested task by launching Claude in Terminal
    func executeTask(_ task: SuggestedTask) {
        let prompt = PromptBuilder.buildExecutionPrompt(task: task)

        // Determine working directory from source info
        var workingDirectory: String? = nil
        if let sourceInfo = task.sourceInfo,
           let filePath = sourceInfo.filePath {
            let url = URL(fileURLWithPath: filePath)
            workingDirectory = url.deletingLastPathComponent().path
        }

        // Use the suggested command if available, otherwise build one
        if let suggestedCommand = task.suggestedCommand, !suggestedCommand.isEmpty {
            TerminalLauncher.launch(command: suggestedCommand)
        } else {
            TerminalLauncher.launchClaude(prompt: prompt, workingDirectory: workingDirectory)
        }
    }

    /// Launch Claude with a custom prompt
    func launchWithPrompt(_ prompt: String, workingDirectory: String? = nil) {
        TerminalLauncher.launchClaude(prompt: prompt, workingDirectory: workingDirectory)
    }

    /// Open Claude Code in a specific project directory
    func openProject(at path: String) {
        TerminalLauncher.launch(command: "claude", workingDirectory: path)
    }

    /// Execute a specific action step
    func executeStep(_ step: ActionStep, task: SuggestedTask) {
        if let command = step.command {
            // Execute the specific command
            var workingDirectory: String? = nil
            if let sourceInfo = task.sourceInfo,
               let filePath = sourceInfo.filePath {
                let url = URL(fileURLWithPath: filePath)
                workingDirectory = url.deletingLastPathComponent().path
            }
            TerminalLauncher.launch(command: command, workingDirectory: workingDirectory)
        } else {
            // Build a prompt for this step
            let prompt = """
            I need help with step \(step.stepNumber) of a task:

            Task: \(task.title)
            Step: \(step.description)

            Please help me complete this step.
            """
            TerminalLauncher.launchClaude(prompt: prompt)
        }
    }
}
