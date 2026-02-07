import Foundation

// MARK: - Task Feedback Store

/// Persists completed/dismissed task feedback for the historical feedback loop.
final class TaskFeedbackStore {
    static let shared = TaskFeedbackStore()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Max records kept per (sourceType, sourceName) pair
    private let maxRecordsPerSource = 50
    /// Records older than this are pruned
    private let retentionDays = 30

    private var records: [FeedbackRecord] = []

    private var feedbackURL: URL {
        appSupportDirectory.appendingPathComponent("feedback.json")
    }

    private var appSupportDirectory: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("WhatsNext")
        if !fileManager.fileExists(atPath: appSupport.path) {
            try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        return appSupport
    }

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        load()
    }

    // MARK: - Public Methods

    /// Record a task outcome (completed or dismissed)
    func recordOutcome(_ record: FeedbackRecord) {
        records.append(record)
        pruneIfNeeded()
        save()
    }

    /// Returns records from the last `days` days
    func recentRecords(within days: Int = 30) -> [FeedbackRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return records.filter { $0.resolvedAt >= cutoff }
    }

    // MARK: - Private Methods

    /// Drop records older than retention period and cap per source
    private func pruneIfNeeded() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()

        // Remove expired records
        records = records.filter { $0.resolvedAt >= cutoff }

        // Cap per source: group by (sourceType, sourceName), keep newest maxRecordsPerSource
        let grouped = Dictionary(grouping: records) { "\($0.sourceType.rawValue)|\($0.sourceName)" }
        var pruned: [FeedbackRecord] = []

        for (_, group) in grouped {
            let sorted = group.sorted { $0.resolvedAt > $1.resolvedAt }
            pruned.append(contentsOf: sorted.prefix(maxRecordsPerSource))
        }

        records = pruned.sorted { $0.resolvedAt > $1.resolvedAt }
    }

    private func save() {
        do {
            let data = try encoder.encode(records)
            try data.write(to: feedbackURL, options: .atomic)
        } catch {
            print("Failed to save feedback: \(error)")
        }
    }

    private func load() {
        guard fileManager.fileExists(atPath: feedbackURL.path) else { return }
        do {
            let data = try Data(contentsOf: feedbackURL)
            records = try decoder.decode([FeedbackRecord].self, from: data)
        } catch {
            print("Failed to load feedback: \(error)")
        }
    }
}
