import Foundation

// MARK: - TODO Scanner Strategy

/// Scans files for TODO, FIXME, HACK, and other actionable comments
final class TodoScannerStrategy: ExplorationStrategy {
    let id = "todo-scanner"
    let name = "TODO Scanner"
    let strategyDescription = "Find TODO, FIXME, HACK, and NOTE comments in code"

    private let fileManager = FileManager.default

    // Patterns to search for (case insensitive)
    private let patterns: [(pattern: String, type: FindingType, severity: FindingSeverity)] = [
        ("TODO", .todo, .info),
        ("FIXME", .fixme, .warning),
        ("HACK", .hack, .warning),
        ("XXX", .hack, .warning),
        ("BUG", .fixme, .critical),
        ("NOTE", .note, .debug),
        ("OPTIMIZE", .todo, .info),
        ("REVIEW", .todo, .info)
    ]

    // MARK: - ExplorationStrategy

    func canExplore(at path: URL) async -> Bool {
        // Can explore any directory
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func explore(at path: URL, config: FolderExplorationConfig) async throws -> ExplorationResult {
        var findings: [ExplorationFinding] = []

        // Get files to scan
        let files = ExplorationEngine.shared.enumerateFiles(
            at: path,
            maxDepth: config.maxDepth,
            filePatterns: config.filePatterns,
            excludePatterns: config.excludePatterns,
            maxFiles: config.maxFilesToAnalyze
        )

        // Scan each file
        for fileURL in files {
            let fileFindings = scanFile(fileURL, basePath: path)
            findings.append(contentsOf: fileFindings)
        }

        // Sort by severity then by file
        findings.sort { ($0.severity, $0.filePath ?? "") < ($1.severity, $1.filePath ?? "") }

        // Build summary
        let todoCounts = Dictionary(grouping: findings) { $0.findingType }
        let summaryParts = todoCounts.map { "\($0.key.displayName): \($0.value.count)" }
        let summary = summaryParts.isEmpty ? "No action items found" : summaryParts.joined(separator: ", ")

        return ExplorationResult(
            strategyId: id,
            strategyName: name,
            sourcePath: path,
            findings: findings,
            summary: summary
        )
    }

    // MARK: - Private Methods

    private func scanFile(_ fileURL: URL, basePath: URL) -> [ExplorationFinding] {
        var findings: [ExplorationFinding] = []

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return findings
        }

        let lines = content.components(separatedBy: .newlines)
        let relativePath = fileURL.path.replacingOccurrences(of: basePath.path + "/", with: "")

        for (lineIndex, line) in lines.enumerated() {
            let lineNumber = lineIndex + 1
            let upperLine = line.uppercased()

            for (pattern, findingType, severity) in patterns {
                if upperLine.contains(pattern) {
                    // Extract the actual comment text
                    let commentText = extractCommentText(from: line, pattern: pattern)

                    findings.append(ExplorationFinding(
                        findingType: findingType,
                        title: "\(pattern): \(commentText.prefix(60))\(commentText.count > 60 ? "..." : "")",
                        description: commentText,
                        filePath: relativePath,
                        lineNumber: lineNumber,
                        severity: severity
                    ))
                }
            }
        }

        return findings
    }

    private func extractCommentText(from line: String, pattern: String) -> String {
        // Try to extract text after the pattern
        let upperLine = line.uppercased()
        guard let range = upperLine.range(of: pattern) else {
            return line.trimmingCharacters(in: .whitespaces)
        }

        let startIndex = line.index(line.startIndex, offsetBy: line.distance(from: line.startIndex, to: range.upperBound))
        var text = String(line[startIndex...])

        // Clean up common prefixes
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: ": -").union(.whitespaces))

        // Remove trailing comment markers
        if let commentEnd = text.firstIndex(of: "*") {
            text = String(text[..<commentEnd])
        }

        return text.trimmingCharacters(in: .whitespaces)
    }
}
