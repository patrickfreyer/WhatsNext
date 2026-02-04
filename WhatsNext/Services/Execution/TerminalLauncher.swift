import AppKit
import Foundation

// MARK: - Terminal Launcher

/// Launches commands in Terminal.app
enum TerminalLauncher {

    /// Launch a command in Terminal
    static func launch(command: String, workingDirectory: String? = nil) {
        var script = ""

        if let dir = workingDirectory {
            script = """
            tell application "Terminal"
                activate
                do script "cd '\(escapeForAppleScript(dir))' && \(escapeForAppleScript(command))"
            end tell
            """
        } else {
            script = """
            tell application "Terminal"
                activate
                do script "\(escapeForAppleScript(command))"
            end tell
            """
        }

        executeAppleScript(script)
    }

    /// Launch Claude with a specific prompt in Terminal
    static func launchClaude(prompt: String, workingDirectory: String? = nil) {
        // Escape the prompt for shell
        let escapedPrompt = escapeForShell(prompt)
        let command = "claude \"\(escapedPrompt)\""
        launch(command: command, workingDirectory: workingDirectory)
    }

    /// Open a new Terminal window at a specific directory
    static func openTerminal(at directory: String) {
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(escapeForAppleScript(directory))'"
        end tell
        """
        executeAppleScript(script)
    }

    // MARK: - Private Helpers

    private static func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func escapeForShell(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
    }

    private static func executeAppleScript(_ script: String) {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        }
    }
}
