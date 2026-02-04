import Foundation

// MARK: - Exploration Engine

/// Orchestrates exploration strategies for directory analysis
final class ExplorationEngine {
    static let shared = ExplorationEngine()

    private let registry = ExplorationStrategyRegistry.shared
    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Public Methods

    /// Run all enabled strategies on a directory
    func explore(
        at path: URL,
        config: FolderExplorationConfig
    ) async throws -> [ExplorationResult] {
        // Validate path
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ExplorationStrategyError.notADirectory(path.path)
        }

        // Get enabled strategies
        let strategies = registry.enabledStrategies(ids: config.enabledStrategies)

        if strategies.isEmpty {
            return []
        }

        // Run strategies concurrently
        return await withTaskGroup(of: ExplorationResult?.self) { group in
            for strategy in strategies {
                group.addTask {
                    do {
                        // Check if strategy can explore this path
                        guard await strategy.canExplore(at: path) else {
                            return nil
                        }
                        return try await strategy.explore(at: path, config: config)
                    } catch {
                        print("Strategy \(strategy.id) failed: \(error)")
                        return nil
                    }
                }
            }

            var results: [ExplorationResult] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            return results
        }
    }

    /// Run a single strategy on a directory
    func runStrategy(
        _ strategyId: String,
        at path: URL,
        config: FolderExplorationConfig
    ) async throws -> ExplorationResult? {
        guard let strategy = registry.strategy(for: strategyId) else {
            return nil
        }

        guard await strategy.canExplore(at: path) else {
            return nil
        }

        return try await strategy.explore(at: path, config: config)
    }

    /// Get all available strategy IDs
    func availableStrategyIds() -> [String] {
        registry.allStrategies().map { $0.id }
    }

    /// Get strategy info
    func strategyInfo(for id: String) -> (name: String, description: String)? {
        guard let strategy = registry.strategy(for: id) else { return nil }
        return (strategy.name, strategy.strategyDescription)
    }
}

// MARK: - File Utilities

extension ExplorationEngine {

    /// Check if a file matches any of the given patterns
    func fileMatchesPatterns(_ fileName: String, patterns: [String]) -> Bool {
        for pattern in patterns {
            if matchesGlobPattern(fileName, pattern: pattern) {
                return true
            }
        }
        return false
    }

    /// Check if a path should be excluded
    func shouldExclude(_ path: URL, excludePatterns: [String]) -> Bool {
        let pathComponents = path.pathComponents
        for pattern in excludePatterns {
            if pathComponents.contains(pattern) {
                return true
            }
            if matchesGlobPattern(path.lastPathComponent, pattern: pattern) {
                return true
            }
        }
        return false
    }

    /// Simple glob pattern matching (supports * wildcard)
    private func matchesGlobPattern(_ string: String, pattern: String) -> Bool {
        if pattern == "*" { return true }

        if pattern.hasPrefix("*.") {
            // Extension match
            let ext = String(pattern.dropFirst(2))
            return string.hasSuffix(".\(ext)")
        }

        if pattern.hasSuffix(".*") {
            // Prefix match
            let prefix = String(pattern.dropLast(2))
            return string.hasPrefix(prefix)
        }

        if pattern.contains("*") {
            // Convert glob to regex
            let regexPattern = "^" + NSRegularExpression.escapedPattern(for: pattern)
                .replacingOccurrences(of: "\\*", with: ".*") + "$"
            return string.range(of: regexPattern, options: .regularExpression) != nil
        }

        return string == pattern
    }

    /// Enumerate files in directory with depth limit
    func enumerateFiles(
        at path: URL,
        maxDepth: Int,
        filePatterns: [String],
        excludePatterns: [String],
        maxFiles: Int
    ) -> [URL] {
        var files: [URL] = []
        let baseDepth = path.pathComponents.count

        guard let enumerator = fileManager.enumerator(
            at: path,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return files
        }

        while let fileURL = enumerator.nextObject() as? URL {
            // Check depth
            let currentDepth = fileURL.pathComponents.count - baseDepth
            if currentDepth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            // Check exclusions
            if shouldExclude(fileURL, excludePatterns: excludePatterns) {
                enumerator.skipDescendants()
                continue
            }

            // Check if it's a file
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard resourceValues.isRegularFile == true else { continue }
            } catch {
                continue
            }

            // Check if matches patterns
            if fileMatchesPatterns(fileURL.lastPathComponent, patterns: filePatterns) {
                files.append(fileURL)
                if files.count >= maxFiles {
                    break
                }
            }
        }

        return files
    }
}
