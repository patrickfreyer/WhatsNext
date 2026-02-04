import Foundation

// MARK: - Website Source Provider

/// Provider for fetching content from websites
final class WebsiteSourceProvider: SourceProvider {
    let id: UUID
    var name: String
    let sourceType: SourceType = .website
    var isEnabled: Bool

    private let configuration: WebsiteSourceConfiguration
    private let session: URLSession

    init(configuration: WebsiteSourceConfiguration) {
        self.id = configuration.id
        self.name = configuration.name
        self.isEnabled = configuration.isEnabled
        self.configuration = configuration

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - SourceProvider

    func fetchItems() async throws -> [SourceItem] {
        guard let url = URL(string: configuration.url) else {
            throw SourceProviderError.configurationInvalid("Invalid URL: \(configuration.url)")
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SourceProviderError.fetchFailed("Failed to fetch URL: \(configuration.url)")
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw SourceProviderError.fetchFailed("Could not decode response")
        }

        // Extract text content from HTML
        let textContent = extractTextFromHTML(html)
        let title = extractTitle(from: html) ?? name

        var metadata = SourceItemMetadata()
        metadata.url = url
        metadata.pageTitle = title
        metadata.lastUpdated = Date()

        let item = SourceItem(
            sourceType: .website,
            sourceName: name,
            title: title,
            content: String(textContent.prefix(2000)),
            metadata: metadata
        )

        return [item]
    }

    func validateConfiguration() -> Bool {
        guard let url = URL(string: configuration.url) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    func checkPermissions() async -> Bool {
        // Websites don't need special permissions
        return true
    }

    func requestPermissions() async throws {
        // No permissions needed for web requests
    }

    // MARK: - Private Methods

    private func extractTextFromHTML(_ html: String) -> String {
        var text = html

        // Remove script and style tags with their content
        text = text.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "<style[^>]*>[\\s\\S]*?</style>",
            with: "",
            options: .regularExpression
        )

        // Remove all HTML tags
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        // Decode HTML entities
        text = decodeHTMLEntities(text)

        // Clean up whitespace
        text = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTitle(from html: String) -> String? {
        let pattern = "<title[^>]*>([^<]+)</title>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let titleRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        let title = String(html[titleRange])
        return decodeHTMLEntities(title).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&nbsp;": " ",
            "&mdash;": "—",
            "&ndash;": "–",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™"
        ]

        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }

        return result
    }
}
