import Foundation

// MARK: - Feedback Summarizer

/// Builds a prompt section summarizing historical task feedback per source.
enum FeedbackSummarizer {

    /// Build the feedback section for injection into the analysis prompt.
    /// Returns nil when there are no records (cold start).
    static func buildFeedbackSection(records: [FeedbackRecord]) -> String? {
        guard !records.isEmpty else { return nil }

        // Group by (sourceType, sourceName)
        let grouped = Dictionary(grouping: records) {
            SourceKey(type: $0.sourceType, name: $0.sourceName)
        }

        var lines: [String] = []
        lines.append("=== HISTORICAL FEEDBACK ===")
        lines.append("")
        lines.append("The user has previously acted on suggested tasks. Use this history to calibrate your suggestions:")
        lines.append("- Generate MORE tasks similar to completed ones (the user found these valuable)")
        lines.append("- AVOID generating tasks similar to dismissed ones (the user found these unhelpful)")
        lines.append("")

        for (key, group) in grouped.sorted(by: { $0.key.name < $1.key.name }) {
            let completed = group.filter { $0.outcome == .completed }
            let dismissed = group.filter { $0.outcome == .dismissed }
            let total = group.count
            let rate = total > 0 ? Int(Double(completed.count) / Double(total) * 100) : 0

            lines.append("[\(key.type.displayName): \(key.name)] \(completed.count) completed, \(dismissed.count) dismissed (\(rate)% acceptance rate)")

            // Completed: show full titles + descriptions so Claude knows exactly what worked
            if !completed.isEmpty {
                lines.append("  ACCEPTED tasks (generate similar ones):")
                for task in completed.suffix(8) {
                    lines.append("    - \"\(task.taskTitle)\"")
                    let desc = truncate(task.taskDescription, to: 120)
                    lines.append("      Context: \(desc)")
                }
                // Show keyword patterns
                let completedKeywords = extractTopKeywords(from: completed.map(\.taskTitle), top: 5)
                if !completedKeywords.isEmpty {
                    lines.append("  Accepted keywords: \(completedKeywords.joined(separator: ", "))")
                }
            }

            // Dismissed: show full titles so Claude knows what to avoid
            if !dismissed.isEmpty {
                lines.append("  DISMISSED tasks (avoid similar ones):")
                for task in dismissed.suffix(6) {
                    lines.append("    - \"\(task.taskTitle)\"")
                }
                let dismissedKeywords = extractTopKeywords(from: dismissed.map(\.taskTitle), top: 4)
                if !dismissedKeywords.isEmpty {
                    lines.append("  Dismissed keywords: \(dismissedKeywords.joined(separator: ", "))")
                }
            }

            lines.append("")
        }

        // Trim to stay within ~500 token budget
        let result = lines.joined(separator: "\n")
        if result.count > 2000 {
            return String(result.prefix(2000)) + "\n... (feedback truncated)"
        }
        return result
    }

    // MARK: - Helpers

    private static func extractTopKeywords(from titles: [String], top: Int) -> [String] {
        let stopWords: Set<String> = [
            "the", "a", "an", "in", "on", "at", "to", "for", "of", "and",
            "or", "is", "it", "with", "from", "by", "this", "that", "your",
            "you", "be", "as", "are", "was", "not", "but", "if", "has", "have"
        ]

        var counts: [String: Int] = [:]
        for title in titles {
            let words = title.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 && !stopWords.contains($0) }
            for word in Set(words) {
                counts[word, default: 0] += 1
            }
        }

        return counts
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(top)
            .map { "\"\($0.key)\" (x\($0.value))" }
    }

    private static func truncate(_ text: String, to maxLength: Int) -> String {
        if text.count <= maxLength { return text }
        return String(text.prefix(maxLength)) + "..."
    }
}

// MARK: - Source Key (grouping helper)

private struct SourceKey: Hashable {
    let type: SourceType
    let name: String
}
