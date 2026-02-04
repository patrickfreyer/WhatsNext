import Foundation

// MARK: - Recent Changes Strategy

/// Identifies recently modified or created files
final class RecentChangesStrategy: ExplorationStrategy {
    let id = "recent-changes"
    let name = "Recent Changes"
    let strategyDescription = "Find files that were recently modified or created"

    private let fileManager = FileManager.default
    private let explorationEngine = ExplorationEngine.shared

    // Time thresholds
    private let veryRecentHours: TimeInterval = 24
    private let recentDays: TimeInterval = 7

    // MARK: - ExplorationStrategy

    func canExplore(at path: URL) async -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func explore(at path: URL, config: FolderExplorationConfig) async throws -> ExplorationResult {
        var findings: [ExplorationFinding] = []
        let now = Date()

        // Get files to check
        let files = explorationEngine.enumerateFiles(
            at: path,
            maxDepth: config.maxDepth,
            filePatterns: config.filePatterns,
            excludePatterns: config.excludePatterns,
            maxFiles: config.maxFilesToAnalyze * 2 // Get more files to filter
        )

        var veryRecentFiles: [(URL, Date)] = []
        var recentFiles: [(URL, Date)] = []

        for fileURL in files {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
                guard let modDate = resourceValues.contentModificationDate else { continue }

                let hoursAgo = now.timeIntervalSince(modDate) / 3600
                let relativePath = fileURL.path.replacingOccurrences(of: path.path + "/", with: "")

                if hoursAgo <= veryRecentHours {
                    veryRecentFiles.append((fileURL, modDate))
                } else if hoursAgo <= recentDays * 24 {
                    recentFiles.append((fileURL, modDate))
                }
            } catch {
                continue
            }
        }

        // Sort by modification date (most recent first)
        veryRecentFiles.sort { $0.1 > $1.1 }
        recentFiles.sort { $0.1 > $1.1 }

        // Add findings for very recent files (last 24 hours)
        for (fileURL, modDate) in veryRecentFiles.prefix(10) {
            let relativePath = fileURL.path.replacingOccurrences(of: path.path + "/", with: "")
            let timeAgo = formatTimeAgo(from: modDate)

            findings.append(ExplorationFinding(
                findingType: .recentlyModified,
                title: "Recently modified: \(fileURL.lastPathComponent)",
                description: "Modified \(timeAgo)",
                filePath: relativePath,
                severity: .info,
                metadata: ["modifiedAt": ISO8601DateFormatter().string(from: modDate)]
            ))
        }

        // Add findings for files modified in last week (not in last 24 hours)
        for (fileURL, modDate) in recentFiles.prefix(10) {
            let relativePath = fileURL.path.replacingOccurrences(of: path.path + "/", with: "")
            let timeAgo = formatTimeAgo(from: modDate)

            findings.append(ExplorationFinding(
                findingType: .recentlyModified,
                title: "Modified this week: \(fileURL.lastPathComponent)",
                description: "Modified \(timeAgo)",
                filePath: relativePath,
                severity: .debug,
                metadata: ["modifiedAt": ISO8601DateFormatter().string(from: modDate)]
            ))
        }

        // Build summary
        var summaryParts: [String] = []
        if !veryRecentFiles.isEmpty {
            summaryParts.append("\(veryRecentFiles.count) files modified in last 24h")
        }
        if !recentFiles.isEmpty {
            summaryParts.append("\(recentFiles.count) files modified this week")
        }
        let summary = summaryParts.isEmpty ? "No recent changes" : summaryParts.joined(separator: ", ")

        return ExplorationResult(
            strategyId: id,
            strategyName: name,
            sourcePath: path,
            findings: findings,
            summary: summary
        )
    }

    // MARK: - Private Methods

    private func formatTimeAgo(from date: Date) -> String {
        let now = Date()
        let seconds = now.timeIntervalSince(date)

        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(seconds / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}
