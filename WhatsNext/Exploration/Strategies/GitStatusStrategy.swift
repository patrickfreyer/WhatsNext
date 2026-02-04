import Foundation

// MARK: - Git Status Strategy

/// Analyzes git repository status for uncommitted changes, branches, etc.
final class GitStatusStrategy: ExplorationStrategy {
    let id = "git-status"
    let name = "Git Status"
    let strategyDescription = "Check for uncommitted changes, untracked files, and branch status"

    private let fileManager = FileManager.default

    // MARK: - ExplorationStrategy

    func canExplore(at path: URL) async -> Bool {
        // Check if .git directory exists
        let gitPath = path.appendingPathComponent(".git")
        return fileManager.fileExists(atPath: gitPath.path)
    }

    func explore(at path: URL, config: FolderExplorationConfig) async throws -> ExplorationResult {
        var findings: [ExplorationFinding] = []
        var summaryParts: [String] = []

        // Get current branch
        if let branch = runGitCommand("rev-parse", "--abbrev-ref", "HEAD", at: path) {
            summaryParts.append("Branch: \(branch)")

            // Check if ahead/behind
            if let aheadBehind = getAheadBehind(at: path) {
                if aheadBehind.ahead > 0 {
                    findings.append(ExplorationFinding(
                        findingType: .gitAhead,
                        title: "Commits ahead of remote",
                        description: "\(aheadBehind.ahead) commit(s) not pushed to remote",
                        severity: .warning
                    ))
                    summaryParts.append("Ahead: \(aheadBehind.ahead)")
                }
                if aheadBehind.behind > 0 {
                    findings.append(ExplorationFinding(
                        findingType: .gitBehind,
                        title: "Commits behind remote",
                        description: "\(aheadBehind.behind) commit(s) behind remote",
                        severity: .warning
                    ))
                    summaryParts.append("Behind: \(aheadBehind.behind)")
                }
            }
        }

        // Get status (uncommitted changes)
        if let status = runGitCommand("status", "--porcelain", at: path) {
            let lines = status.split(separator: "\n")

            var modifiedFiles: [String] = []
            var untrackedFiles: [String] = []
            var stagedFiles: [String] = []

            for line in lines {
                let statusLine = String(line)
                guard statusLine.count > 3 else { continue }

                let indexStatus = statusLine[statusLine.startIndex]
                let workTreeStatus = statusLine[statusLine.index(statusLine.startIndex, offsetBy: 1)]
                let filePath = String(statusLine.dropFirst(3))

                if indexStatus != " " && indexStatus != "?" {
                    stagedFiles.append(filePath)
                }

                if workTreeStatus == "M" || workTreeStatus == "D" {
                    modifiedFiles.append(filePath)
                }

                if statusLine.hasPrefix("??") {
                    untrackedFiles.append(filePath)
                }
            }

            // Add findings for uncommitted changes
            if !modifiedFiles.isEmpty {
                findings.append(ExplorationFinding(
                    findingType: .gitUncommitted,
                    title: "Modified files",
                    description: "Files with uncommitted changes: \(modifiedFiles.joined(separator: ", "))",
                    severity: .warning,
                    metadata: ["files": modifiedFiles.joined(separator: ",")]
                ))
                summaryParts.append("Modified: \(modifiedFiles.count)")
            }

            if !stagedFiles.isEmpty {
                findings.append(ExplorationFinding(
                    findingType: .gitUncommitted,
                    title: "Staged changes",
                    description: "Staged but not committed: \(stagedFiles.joined(separator: ", "))",
                    severity: .info,
                    metadata: ["files": stagedFiles.joined(separator: ",")]
                ))
                summaryParts.append("Staged: \(stagedFiles.count)")
            }

            if !untrackedFiles.isEmpty {
                findings.append(ExplorationFinding(
                    findingType: .gitUntracked,
                    title: "Untracked files",
                    description: "New files not added to git: \(untrackedFiles.prefix(10).joined(separator: ", "))\(untrackedFiles.count > 10 ? "..." : "")",
                    severity: .info,
                    metadata: ["count": String(untrackedFiles.count)]
                ))
                summaryParts.append("Untracked: \(untrackedFiles.count)")
            }
        }

        // Get recent commits
        if let log = runGitCommand("log", "--oneline", "-5", at: path) {
            let commits = log.split(separator: "\n").map { String($0) }
            if !commits.isEmpty {
                summaryParts.append("Recent commits: \(commits.count)")
            }
        }

        return ExplorationResult(
            strategyId: id,
            strategyName: name,
            sourcePath: path,
            findings: findings,
            summary: summaryParts.isEmpty ? "Clean git repository" : summaryParts.joined(separator: " | ")
        )
    }

    // MARK: - Private Methods

    private func runGitCommand(_ args: String..., at path: URL) -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path.path] + args
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func getAheadBehind(at path: URL) -> (ahead: Int, behind: Int)? {
        guard let output = runGitCommand("rev-list", "--left-right", "--count", "@{upstream}...HEAD", at: path) else {
            return nil
        }

        let parts = output.split(separator: "\t")
        guard parts.count == 2,
              let behind = Int(parts[0]),
              let ahead = Int(parts[1]) else {
            return nil
        }

        return (ahead, behind)
    }
}
