import Foundation

// MARK: - Folder Source Provider

/// Provider for analyzing local folders and their contents
final class FolderSourceProvider: SourceProvider, ExplorableSourceProvider {
    let id: UUID
    var name: String
    let sourceType: SourceType = .folder
    var isEnabled: Bool

    private let configuration: FolderSourceConfiguration
    private let fileManager = FileManager.default

    init(configuration: FolderSourceConfiguration) {
        self.id = configuration.id
        self.name = configuration.name
        self.isEnabled = configuration.isEnabled
        self.configuration = configuration
    }

    // MARK: - SourceProvider

    func fetchItems() async throws -> [SourceItem] {
        let path = expandPath(configuration.path)
        let url = URL(fileURLWithPath: path)

        guard fileManager.fileExists(atPath: url.path) else {
            throw SourceProviderError.configurationInvalid("Path does not exist: \(path)")
        }

        var items: [SourceItem] = []

        // Get files matching patterns
        let files = enumerateFiles(
            at: url,
            maxDepth: configuration.exploration.maxDepth,
            patterns: configuration.exploration.filePatterns,
            excludePatterns: configuration.exploration.excludePatterns,
            maxFiles: configuration.exploration.maxFilesToAnalyze
        )

        for fileURL in files {
            if let item = createSourceItem(from: fileURL, basePath: url) {
                items.append(item)
            }
        }

        return items
    }

    func validateConfiguration() -> Bool {
        let path = expandPath(configuration.path)
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func checkPermissions() async -> Bool {
        let path = expandPath(configuration.path)
        return fileManager.isReadableFile(atPath: path)
    }

    func requestPermissions() async throws {
        // Folder permissions are handled at the OS level
        // If we can't read, user needs to grant Full Disk Access
        let path = expandPath(configuration.path)
        if !fileManager.isReadableFile(atPath: path) {
            throw SourceProviderError.permissionDenied("Cannot read folder. Please grant Full Disk Access in System Preferences.")
        }
    }

    // MARK: - ExplorableSourceProvider

    func explore(with engine: ExplorationEngine) async throws -> [ExplorationResult] {
        let path = expandPath(configuration.path)
        let url = URL(fileURLWithPath: path)

        guard fileManager.fileExists(atPath: url.path) else {
            throw SourceProviderError.configurationInvalid("Path does not exist: \(path)")
        }

        return try await engine.explore(at: url, config: configuration.exploration)
    }

    // MARK: - Private Methods

    private func expandPath(_ path: String) -> String {
        if path.hasPrefix("~") {
            return (path as NSString).expandingTildeInPath
        }
        return path
    }

    private func enumerateFiles(
        at url: URL,
        maxDepth: Int,
        patterns: [String],
        excludePatterns: [String],
        maxFiles: Int
    ) -> [URL] {
        var files: [URL] = []
        let baseDepth = url.pathComponents.count

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return files
        }

        while let fileURL = enumerator.nextObject() as? URL {
            let currentDepth = fileURL.pathComponents.count - baseDepth
            if currentDepth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            // Check exclusions
            let shouldExclude = excludePatterns.contains { pattern in
                fileURL.pathComponents.contains(pattern) ||
                fileURL.lastPathComponent == pattern
            }
            if shouldExclude {
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
            let fileName = fileURL.lastPathComponent
            let matchesPattern = patterns.contains { pattern in
                matchesGlobPattern(fileName, pattern: pattern)
            }

            if matchesPattern {
                files.append(fileURL)
                if files.count >= maxFiles {
                    break
                }
            }
        }

        return files
    }

    private func matchesGlobPattern(_ string: String, pattern: String) -> Bool {
        if pattern == "*" { return true }

        if pattern.hasPrefix("*.") {
            let ext = String(pattern.dropFirst(2))
            return string.hasSuffix(".\(ext)")
        }

        if pattern.hasSuffix(".*") {
            let prefix = String(pattern.dropLast(2))
            return string.hasPrefix(prefix)
        }

        return string == pattern
    }

    private func createSourceItem(from fileURL: URL, basePath: URL) -> SourceItem? {
        let relativePath = fileURL.path.replacingOccurrences(of: basePath.path + "/", with: "")

        // Read file content (limited)
        var content = ""
        if let data = fileManager.contents(atPath: fileURL.path),
           let text = String(data: data, encoding: .utf8) {
            content = String(text.prefix(1000))
        }

        // Get file metadata
        var metadata = SourceItemMetadata()
        metadata.filePath = fileURL.path
        metadata.fileType = fileURL.pathExtension

        if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path) {
            metadata.fileSize = attributes[.size] as? Int64
            metadata.modifiedDate = attributes[.modificationDate] as? Date
        }

        return SourceItem(
            sourceType: .folder,
            sourceName: name,
            title: relativePath,
            content: content,
            metadata: metadata
        )
    }
}
