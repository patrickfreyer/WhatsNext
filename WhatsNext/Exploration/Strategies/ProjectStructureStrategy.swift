import Foundation

// MARK: - Project Structure Strategy

/// Analyzes project structure to identify entry points, dependencies, and configuration files
final class ProjectStructureStrategy: ExplorationStrategy {
    let id = "project-structure"
    let name = "Project Structure"
    let strategyDescription = "Analyze project layout, find entry points, dependencies, and config files"

    private let fileManager = FileManager.default

    // Known project indicators
    private let projectIndicators: [(file: String, type: String)] = [
        ("Package.swift", "Swift Package"),
        ("Podfile", "CocoaPods"),
        ("Cartfile", "Carthage"),
        ("package.json", "Node.js"),
        ("Cargo.toml", "Rust"),
        ("build.gradle", "Gradle"),
        ("pom.xml", "Maven"),
        ("requirements.txt", "Python"),
        ("Gemfile", "Ruby"),
        ("CMakeLists.txt", "CMake"),
        ("Makefile", "Make"),
        ("docker-compose.yml", "Docker Compose"),
        ("Dockerfile", "Docker"),
        (".xcodeproj", "Xcode Project"),
        (".xcworkspace", "Xcode Workspace")
    ]

    // Entry point patterns
    private let entryPointPatterns: [(pattern: String, description: String)] = [
        ("main.swift", "Swift entry point"),
        ("AppDelegate.swift", "iOS/macOS app delegate"),
        ("App.swift", "SwiftUI app entry"),
        ("index.js", "Node.js entry point"),
        ("index.ts", "TypeScript entry point"),
        ("main.py", "Python entry point"),
        ("main.rs", "Rust entry point"),
        ("Main.java", "Java entry point")
    ]

    // Config file patterns
    private let configPatterns: [String] = [
        ".env",
        ".env.local",
        "config.json",
        "config.yaml",
        "config.yml",
        "settings.json",
        ".eslintrc",
        ".prettierrc",
        "tsconfig.json",
        "babel.config.js",
        "webpack.config.js",
        ".swiftlint.yml"
    ]

    // MARK: - ExplorationStrategy

    func canExplore(at path: URL) async -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func explore(at path: URL, config: FolderExplorationConfig) async throws -> ExplorationResult {
        var findings: [ExplorationFinding] = []
        var projectTypes: [String] = []

        // Check for project indicators
        let contents = try fileManager.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)

        for item in contents {
            let name = item.lastPathComponent

            // Check project type indicators
            for (file, type) in projectIndicators {
                if name == file || name.hasSuffix(file) {
                    projectTypes.append(type)
                    findings.append(ExplorationFinding(
                        findingType: .projectStructure,
                        title: "\(type) project detected",
                        description: "Found \(name)",
                        filePath: name,
                        severity: .info
                    ))
                }
            }

            // Check for entry points
            for (pattern, description) in entryPointPatterns {
                if name == pattern {
                    findings.append(ExplorationFinding(
                        findingType: .entryPoint,
                        title: description,
                        description: "Entry point found: \(name)",
                        filePath: name,
                        severity: .info
                    ))
                }
            }

            // Check for config files
            if configPatterns.contains(name) {
                findings.append(ExplorationFinding(
                    findingType: .configFile,
                    title: "Config file: \(name)",
                    description: "Configuration file found",
                    filePath: name,
                    severity: .debug
                ))
            }
        }

        // Analyze directory structure
        let directoryInfo = analyzeDirectoryStructure(at: path, maxDepth: min(2, config.maxDepth))
        findings.append(contentsOf: directoryInfo)

        // Check for dependencies
        let dependencyFindings = await analyzeDependencies(at: path)
        findings.append(contentsOf: dependencyFindings)

        // Build summary
        var summaryParts: [String] = []
        if !projectTypes.isEmpty {
            summaryParts.append("Type: \(projectTypes.joined(separator: ", "))")
        }
        let entryPoints = findings.filter { $0.findingType == .entryPoint }.count
        if entryPoints > 0 {
            summaryParts.append("Entry points: \(entryPoints)")
        }
        let configFiles = findings.filter { $0.findingType == .configFile }.count
        if configFiles > 0 {
            summaryParts.append("Config files: \(configFiles)")
        }

        let summary = summaryParts.isEmpty ? "Unknown project structure" : summaryParts.joined(separator: " | ")

        return ExplorationResult(
            strategyId: id,
            strategyName: name,
            sourcePath: path,
            findings: findings,
            summary: summary
        )
    }

    // MARK: - Private Methods

    private func analyzeDirectoryStructure(at path: URL, maxDepth: Int) -> [ExplorationFinding] {
        var findings: [ExplorationFinding] = []

        guard let enumerator = fileManager.enumerator(
            at: path,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return findings
        }

        let baseDepth = path.pathComponents.count
        var importantDirs: [String] = []

        let knownDirectories = ["src", "lib", "Sources", "Tests", "test", "spec", "docs", "public", "assets", "components", "services", "models", "views", "controllers"]

        while let fileURL = enumerator.nextObject() as? URL {
            let currentDepth = fileURL.pathComponents.count - baseDepth
            if currentDepth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                guard resourceValues.isDirectory == true else { continue }

                let dirName = fileURL.lastPathComponent
                if knownDirectories.contains(dirName) {
                    importantDirs.append(dirName)
                }
            } catch {
                continue
            }
        }

        if !importantDirs.isEmpty {
            findings.append(ExplorationFinding(
                findingType: .projectStructure,
                title: "Project directories",
                description: "Found: \(importantDirs.joined(separator: ", "))",
                severity: .debug
            ))
        }

        return findings
    }

    private func analyzeDependencies(at path: URL) async -> [ExplorationFinding] {
        var findings: [ExplorationFinding] = []

        // Check Package.swift for Swift dependencies
        let packageSwift = path.appendingPathComponent("Package.swift")
        if fileManager.fileExists(atPath: packageSwift.path) {
            if let content = try? String(contentsOf: packageSwift, encoding: .utf8) {
                let dependencyCount = content.components(separatedBy: ".package(").count - 1
                if dependencyCount > 0 {
                    findings.append(ExplorationFinding(
                        findingType: .dependency,
                        title: "Swift Package dependencies",
                        description: "Found \(dependencyCount) package dependencies",
                        filePath: "Package.swift",
                        severity: .info
                    ))
                }
            }
        }

        // Check package.json for Node dependencies
        let packageJson = path.appendingPathComponent("package.json")
        if fileManager.fileExists(atPath: packageJson.path) {
            if let data = try? Data(contentsOf: packageJson),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let deps = (json["dependencies"] as? [String: Any])?.count ?? 0
                let devDeps = (json["devDependencies"] as? [String: Any])?.count ?? 0
                if deps + devDeps > 0 {
                    findings.append(ExplorationFinding(
                        findingType: .dependency,
                        title: "Node.js dependencies",
                        description: "\(deps) dependencies, \(devDeps) dev dependencies",
                        filePath: "package.json",
                        severity: .info
                    ))
                }
            }
        }

        return findings
    }
}
