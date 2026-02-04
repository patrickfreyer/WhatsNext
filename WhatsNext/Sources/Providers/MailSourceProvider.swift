import AppKit
import Foundation

// MARK: - Mail Source Provider

/// Provider for fetching emails from Apple Mail via AppleScript
final class MailSourceProvider: SourceProvider {
    let id = UUID()
    var name: String = "Mail"
    let sourceType: SourceType = .mail
    var isEnabled: Bool

    private let configuration: MailSourceConfiguration

    init(configuration: MailSourceConfiguration) {
        self.isEnabled = configuration.isEnabled
        self.configuration = configuration
    }

    // MARK: - SourceProvider

    func fetchItems() async throws -> [SourceItem] {
        var items: [SourceItem] = []

        for mailbox in configuration.mailboxNames {
            let mailboxItems = try await fetchFromMailbox(mailbox)
            items.append(contentsOf: mailboxItems)
        }

        // Sort by date (newest first)
        items.sort { ($0.metadata.date ?? Date.distantPast) > ($1.metadata.date ?? Date.distantPast) }

        return Array(items.prefix(configuration.maxEmailsToFetch))
    }

    func validateConfiguration() -> Bool {
        return !configuration.mailboxNames.isEmpty
    }

    func checkPermissions() async -> Bool {
        // Try a simple AppleScript to check if we can access Mail
        let script = """
        tell application "Mail"
            return name of first account
        end tell
        """

        return executeAppleScript(script) != nil
    }

    func requestPermissions() async throws {
        // AppleScript permissions are requested automatically by the system
        // If the user hasn't granted them, they'll see a prompt
        let hasPermission = await checkPermissions()
        if !hasPermission {
            throw SourceProviderError.permissionDenied(
                "Mail access not granted. Please allow access in System Preferences > Privacy & Security > Automation"
            )
        }
    }

    // MARK: - Private Methods

    private func fetchFromMailbox(_ mailboxName: String) async throws -> [SourceItem] {
        var filterCondition = ""
        if configuration.onlyUnread && configuration.onlyFlagged {
            filterCondition = "where read status is false or flagged status is true"
        } else if configuration.onlyUnread {
            filterCondition = "where read status is false"
        } else if configuration.onlyFlagged {
            filterCondition = "where flagged status is true"
        }

        let script = """
        tell application "Mail"
            set theMessages to {}
            try
                set theMailbox to mailbox "\(mailboxName)" of first account
                set allMessages to (messages of theMailbox \(filterCondition))
                set maxCount to \(configuration.maxEmailsToFetch)

                repeat with i from 1 to (count of allMessages)
                    if i > maxCount then exit repeat
                    set theMessage to item i of allMessages
                    set messageData to {subject:(subject of theMessage), sender:(sender of theMessage), dateReceived:(date received of theMessage), isRead:(read status of theMessage), isFlagged:(flagged status of theMessage), messageContent:(content of theMessage)}
                    set end of theMessages to messageData
                end repeat
            end try
            return theMessages
        end tell
        """

        guard let result = executeAppleScript(script) else {
            return []
        }

        return parseMailMessages(result, mailbox: mailboxName)
    }

    private func executeAppleScript(_ script: String) -> String? {
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else {
            return nil
        }

        let result = scriptObject.executeAndReturnError(&error)

        if error != nil {
            return nil
        }

        return result.stringValue
    }

    private func parseMailMessages(_ rawResult: String, mailbox: String) -> [SourceItem] {
        // This is a simplified parser - AppleScript list parsing is complex
        // In a production app, you'd want to use a more robust parsing approach
        // or use the Mail.app Scripting Bridge

        var items: [SourceItem] = []

        // For now, create a single item summarizing the mailbox
        // In a real implementation, you'd parse the AppleScript result properly

        // Alternative approach: Use individual AppleScript calls for each property
        items = fetchIndividualMessages(mailbox: mailbox)

        return items
    }

    private func fetchIndividualMessages(mailbox: String) -> [SourceItem] {
        var items: [SourceItem] = []

        // Get message count
        let countScript = """
        tell application "Mail"
            try
                set theMailbox to mailbox "\(mailbox)" of first account
                set unreadMessages to (messages of theMailbox where read status is false)
                return count of unreadMessages
            end try
            return 0
        end tell
        """

        guard let countResult = executeAppleScript(countScript),
              let count = Int(countResult), count > 0 else {
            return items
        }

        // Fetch individual messages
        let maxFetch = min(count, configuration.maxEmailsToFetch)

        for i in 1...maxFetch {
            let messageScript = """
            tell application "Mail"
                try
                    set theMailbox to mailbox "\(mailbox)" of first account
                    set unreadMessages to (messages of theMailbox where read status is false)
                    set theMessage to item \(i) of unreadMessages
                    set msgSubject to subject of theMessage
                    set msgSender to sender of theMessage
                    set msgDate to date received of theMessage
                    set msgFlagged to flagged status of theMessage
                    return msgSubject & "|||" & msgSender & "|||" & (msgDate as string) & "|||" & msgFlagged
                end try
                return ""
            end tell
            """

            if let result = executeAppleScript(messageScript), !result.isEmpty {
                let parts = result.components(separatedBy: "|||")
                if parts.count >= 4 {
                    let subject = parts[0]
                    let sender = parts[1]
                    let dateString = parts[2]
                    let isFlagged = parts[3] == "true"

                    var metadata = SourceItemMetadata()
                    metadata.sender = sender
                    metadata.subject = subject
                    metadata.isUnread = true
                    metadata.isFlagged = isFlagged

                    // Parse date
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm:ss a"
                    metadata.date = dateFormatter.date(from: dateString)

                    let item = SourceItem(
                        sourceType: .mail,
                        sourceName: name,
                        title: subject,
                        content: "From: \(sender)",
                        metadata: metadata
                    )
                    items.append(item)
                }
            }
        }

        return items
    }
}
