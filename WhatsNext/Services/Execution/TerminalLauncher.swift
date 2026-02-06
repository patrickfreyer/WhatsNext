import AppKit
import Foundation

// MARK: - Terminal Launcher

/// Launches commands in iTerm2
enum TerminalLauncher {

    /// Launch a command in iTerm2 (new tab in existing window, or new window if none open)
    static func launch(command: String, workingDirectory: String? = nil) {
        var shellCommand: String

        if let dir = workingDirectory {
            shellCommand = "cd '\(escapeForAppleScript(dir))' && \(escapeForAppleScript(command))"
        } else {
            shellCommand = escapeForAppleScript(command)
        }

        let script = """
        tell application "iTerm2"
            activate
            if (count of windows) = 0 then
                create window with default profile
                tell current session of current window
                    write text "\(shellCommand)"
                end tell
            else
                tell current window
                    create tab with default profile
                    tell current session
                        write text "\(shellCommand)"
                    end tell
                end tell
            end if
        end tell
        """

        executeAppleScript(script)
    }

    /// Launch Claude with a specific prompt in iTerm2
    static func launchClaude(prompt: String, workingDirectory: String? = nil) {
        let escapedPrompt = escapeForShell(prompt)
        let command = "claude \"\(escapedPrompt)\""
        launch(command: command, workingDirectory: workingDirectory)
    }

    /// Open a new iTerm2 tab at a specific directory (or new window if none open)
    static func openTerminal(at directory: String) {
        let script = """
        tell application "iTerm2"
            activate
            if (count of windows) = 0 then
                create window with default profile
                tell current session of current window
                    write text "cd '\(escapeForAppleScript(directory))'"
                end tell
            else
                tell current window
                    create tab with default profile
                    tell current session
                        write text "cd '\(escapeForAppleScript(directory))'"
                    end tell
                end tell
            end if
        end tell
        """
        executeAppleScript(script)
    }

    // MARK: - Private Helpers

    private static func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func escapeForShell(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
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
