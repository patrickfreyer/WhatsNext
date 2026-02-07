import Foundation

// MARK: - Source Item

/// A generic item fetched from any source (folder, website, reminders, mail)
struct SourceItem: Identifiable {
    let id: UUID
    var sourceType: SourceType
    var sourceName: String
    var title: String
    var content: String
    var metadata: SourceItemMetadata
    var fetchedAt: Date

    init(
        id: UUID = UUID(),
        sourceType: SourceType,
        sourceName: String,
        title: String,
        content: String,
        metadata: SourceItemMetadata = SourceItemMetadata(),
        fetchedAt: Date = Date()
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceName = sourceName
        self.title = title
        self.content = content
        self.metadata = metadata
        self.fetchedAt = fetchedAt
    }
}

// MARK: - Source Item Metadata

struct SourceItemMetadata {
    // Common
    var url: URL?
    var date: Date?

    // File-specific
    var filePath: String?
    var lineNumber: Int?
    var fileType: String?
    var fileSize: Int64?
    var modifiedDate: Date?

    // Email-specific
    var sender: String?
    var subject: String?
    var isUnread: Bool?
    var isFlagged: Bool?

    // Reminder-specific
    var dueDate: Date?
    var isCompleted: Bool?
    var reminderPriority: Int?
    var listName: String?

    // Website-specific
    var pageTitle: String?
    var lastUpdated: Date?

    // Git-specific
    var gitBranch: String?
    var gitStatus: String?
    var uncommittedFiles: [String]?

    // Calendar-specific
    var startDate: Date?
    var endDate: Date?
    var eventLocation: String?
    var isAllDay: Bool?
    var attendees: [String]?
    var calendarName: String?

    init(
        url: URL? = nil,
        date: Date? = nil,
        filePath: String? = nil,
        lineNumber: Int? = nil,
        fileType: String? = nil,
        fileSize: Int64? = nil,
        modifiedDate: Date? = nil,
        sender: String? = nil,
        subject: String? = nil,
        isUnread: Bool? = nil,
        isFlagged: Bool? = nil,
        dueDate: Date? = nil,
        isCompleted: Bool? = nil,
        reminderPriority: Int? = nil,
        listName: String? = nil,
        pageTitle: String? = nil,
        lastUpdated: Date? = nil,
        gitBranch: String? = nil,
        gitStatus: String? = nil,
        uncommittedFiles: [String]? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        eventLocation: String? = nil,
        isAllDay: Bool? = nil,
        attendees: [String]? = nil,
        calendarName: String? = nil
    ) {
        self.url = url
        self.date = date
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.fileType = fileType
        self.fileSize = fileSize
        self.modifiedDate = modifiedDate
        self.sender = sender
        self.subject = subject
        self.isUnread = isUnread
        self.isFlagged = isFlagged
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.reminderPriority = reminderPriority
        self.listName = listName
        self.pageTitle = pageTitle
        self.lastUpdated = lastUpdated
        self.gitBranch = gitBranch
        self.gitStatus = gitStatus
        self.uncommittedFiles = uncommittedFiles
        self.startDate = startDate
        self.endDate = endDate
        self.eventLocation = eventLocation
        self.isAllDay = isAllDay
        self.attendees = attendees
        self.calendarName = calendarName
    }
}

// MARK: - Source Item Extensions

extension SourceItem {
    /// Create a summary string for Claude analysis
    var claudeSummary: String {
        var parts: [String] = []

        parts.append("[\(sourceType.displayName): \(sourceName)]")
        parts.append("Title: \(title)")

        if !content.isEmpty {
            let truncatedContent = content.prefix(500)
            parts.append("Content: \(truncatedContent)\(content.count > 500 ? "..." : "")")
        }

        // Add relevant metadata
        switch sourceType {
        case .folder:
            if let path = metadata.filePath {
                parts.append("Path: \(path)")
            }
            if let lineNumber = metadata.lineNumber {
                parts.append("Line: \(lineNumber)")
            }
            if let branch = metadata.gitBranch {
                parts.append("Git Branch: \(branch)")
            }

        case .mail:
            if let sender = metadata.sender {
                parts.append("From: \(sender)")
            }
            if let subject = metadata.subject {
                parts.append("Subject: \(subject)")
            }
            if metadata.isUnread == true {
                parts.append("Status: Unread")
            }
            if metadata.isFlagged == true {
                parts.append("Flagged: Yes")
            }

        case .reminders:
            if let dueDate = metadata.dueDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                parts.append("Due: \(formatter.string(from: dueDate))")
            }
            if let listName = metadata.listName {
                parts.append("List: \(listName)")
            }

        case .website:
            if let url = metadata.url {
                parts.append("URL: \(url.absoluteString)")
            }

        case .calendar:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            if let isAllDay = metadata.isAllDay, isAllDay {
                let dayFormatter = DateFormatter()
                dayFormatter.dateStyle = .medium
                dayFormatter.timeStyle = .none
                if let startDate = metadata.startDate {
                    parts.append("All-day: \(dayFormatter.string(from: startDate))")
                }
            } else if let startDate = metadata.startDate {
                parts.append("Start: \(formatter.string(from: startDate))")
                if let endDate = metadata.endDate {
                    parts.append("End: \(formatter.string(from: endDate))")
                }
            }
            if let location = metadata.eventLocation, !location.isEmpty {
                parts.append("Location: \(location)")
            }
            if let attendees = metadata.attendees, !attendees.isEmpty {
                parts.append("Attendees: \(attendees.joined(separator: ", "))")
            }
            if let calendarName = metadata.calendarName {
                parts.append("Calendar: \(calendarName)")
            }
        }

        return parts.joined(separator: "\n")
    }
}

// MARK: - Source Fetch Result

struct SourceFetchResult {
    var sourceType: SourceType
    var sourceName: String
    var items: [SourceItem]
    var explorationResults: [ExplorationResult]
    var error: Error?
    var fetchedAt: Date

    init(
        sourceType: SourceType,
        sourceName: String,
        items: [SourceItem] = [],
        explorationResults: [ExplorationResult] = [],
        error: Error? = nil,
        fetchedAt: Date = Date()
    ) {
        self.sourceType = sourceType
        self.sourceName = sourceName
        self.items = items
        self.explorationResults = explorationResults
        self.error = error
        self.fetchedAt = fetchedAt
    }

    var isSuccess: Bool {
        error == nil
    }
}
