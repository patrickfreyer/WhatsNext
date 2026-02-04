import Foundation

// MARK: - Exploration Result

/// Result from running an exploration strategy on a directory
struct ExplorationResult: Identifiable {
    let id: UUID
    var strategyId: String
    var strategyName: String
    var sourcePath: URL
    var findings: [ExplorationFinding]
    var summary: String
    var exploredAt: Date

    init(
        id: UUID = UUID(),
        strategyId: String,
        strategyName: String,
        sourcePath: URL,
        findings: [ExplorationFinding] = [],
        summary: String = "",
        exploredAt: Date = Date()
    ) {
        self.id = id
        self.strategyId = strategyId
        self.strategyName = strategyName
        self.sourcePath = sourcePath
        self.findings = findings
        self.summary = summary
        self.exploredAt = exploredAt
    }
}

// MARK: - Exploration Finding

/// A single finding from exploration (TODO, recent change, git status, etc.)
struct ExplorationFinding: Identifiable {
    let id: UUID
    var findingType: FindingType
    var title: String
    var description: String
    var filePath: String?
    var lineNumber: Int?
    var severity: FindingSeverity
    var metadata: [String: String]

    init(
        id: UUID = UUID(),
        findingType: FindingType,
        title: String,
        description: String,
        filePath: String? = nil,
        lineNumber: Int? = nil,
        severity: FindingSeverity = .info,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.findingType = findingType
        self.title = title
        self.description = description
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.severity = severity
        self.metadata = metadata
    }
}

// MARK: - Finding Type

enum FindingType: String, CaseIterable {
    case todo
    case fixme
    case hack
    case note
    case gitUncommitted
    case gitUntracked
    case gitAhead
    case gitBehind
    case recentlyModified
    case recentlyCreated
    case largeFile
    case projectStructure
    case entryPoint
    case dependency
    case configFile
    case other

    var displayName: String {
        switch self {
        case .todo: return "TODO"
        case .fixme: return "FIXME"
        case .hack: return "HACK"
        case .note: return "NOTE"
        case .gitUncommitted: return "Uncommitted Changes"
        case .gitUntracked: return "Untracked Files"
        case .gitAhead: return "Ahead of Remote"
        case .gitBehind: return "Behind Remote"
        case .recentlyModified: return "Recently Modified"
        case .recentlyCreated: return "Recently Created"
        case .largeFile: return "Large File"
        case .projectStructure: return "Project Structure"
        case .entryPoint: return "Entry Point"
        case .dependency: return "Dependency"
        case .configFile: return "Config File"
        case .other: return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .todo: return "checklist"
        case .fixme: return "wrench"
        case .hack: return "exclamationmark.triangle"
        case .note: return "note.text"
        case .gitUncommitted, .gitUntracked: return "arrow.triangle.branch"
        case .gitAhead: return "arrow.up"
        case .gitBehind: return "arrow.down"
        case .recentlyModified, .recentlyCreated: return "clock"
        case .largeFile: return "doc.badge.ellipsis"
        case .projectStructure: return "folder.badge.gearshape"
        case .entryPoint: return "play.fill"
        case .dependency: return "shippingbox"
        case .configFile: return "gearshape"
        case .other: return "questionmark.circle"
        }
    }
}

// MARK: - Finding Severity

enum FindingSeverity: String, CaseIterable, Comparable {
    case critical
    case warning
    case info
    case debug

    var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .warning: return "Warning"
        case .info: return "Info"
        case .debug: return "Debug"
        }
    }

    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .warning: return 1
        case .info: return 2
        case .debug: return 3
        }
    }

    static func < (lhs: FindingSeverity, rhs: FindingSeverity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Exploration Result Extensions

extension ExplorationResult {
    /// Create a summary for Claude analysis
    var claudeSummary: String {
        var parts: [String] = []

        parts.append("=== \(strategyName) ===")
        parts.append("Path: \(sourcePath.path)")

        if !summary.isEmpty {
            parts.append("Summary: \(summary)")
        }

        if !findings.isEmpty {
            parts.append("Findings (\(findings.count)):")
            for finding in findings.prefix(20) {
                var findingLine = "  - [\(finding.findingType.displayName)] \(finding.title)"
                if let filePath = finding.filePath {
                    findingLine += " (\(filePath)"
                    if let line = finding.lineNumber {
                        findingLine += ":\(line)"
                    }
                    findingLine += ")"
                }
                parts.append(findingLine)
            }
            if findings.count > 20 {
                parts.append("  ... and \(findings.count - 20) more")
            }
        }

        return parts.joined(separator: "\n")
    }
}
