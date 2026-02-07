import EventKit
import Foundation

// MARK: - Calendar Source Provider

/// Provider for fetching calendar events from Apple Calendar
final class CalendarSourceProvider: SourceProvider {
    let id = UUID()
    var name: String = "Calendar"
    let sourceType: SourceType = .calendar
    var isEnabled: Bool

    private let configuration: CalendarSourceConfiguration
    private let eventStore = EKEventStore()

    init(configuration: CalendarSourceConfiguration) {
        self.isEnabled = configuration.isEnabled
        self.configuration = configuration
    }

    // MARK: - SourceProvider

    func fetchItems() async throws -> [SourceItem] {
        let hasPermission = await checkPermissions()
        if !hasPermission {
            try await requestPermissions()
        }
        let permissionGranted = await checkPermissions()
        guard permissionGranted else {
            throw SourceProviderError.permissionDenied("Calendar access not granted. Please enable in System Settings > Privacy & Security > Calendars.")
        }

        var items: [SourceItem] = []

        // Get calendars
        let calendars: [EKCalendar]
        if let calendarNames = configuration.calendarNames, !calendarNames.isEmpty {
            calendars = eventStore.calendars(for: .event).filter { calendarNames.contains($0.title) }
        } else {
            calendars = eventStore.calendars(for: .event)
        }

        // Build date range
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -configuration.daysBehind, to: now) ?? now
        let endDate = Calendar.current.date(byAdding: .day, value: configuration.daysAhead, to: now) ?? now

        // Fetch events
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)

        for event in events {
            let item = createSourceItem(from: event)
            items.append(item)
        }

        // Sort by start date (soonest first)
        items.sort { item1, item2 in
            guard let start1 = item1.metadata.startDate, let start2 = item2.metadata.startDate else {
                return item1.metadata.startDate != nil
            }
            return start1 < start2
        }

        return items
    }

    func validateConfiguration() -> Bool {
        return configuration.daysAhead >= 1 && configuration.daysBehind >= 0
    }

    func checkPermissions() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized, .fullAccess:
            return true
        case .writeOnly:
            return false
        case .notDetermined, .restricted, .denied:
            return false
        @unknown default:
            return false
        }
    }

    func requestPermissions() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .notDetermined:
            if #available(macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                if !granted {
                    throw SourceProviderError.permissionDenied("Calendar access was denied")
                }
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                if !granted {
                    throw SourceProviderError.permissionDenied("Calendar access was denied")
                }
            }
        case .restricted:
            throw SourceProviderError.permissionDenied("Calendar access is restricted on this device")
        case .denied:
            throw SourceProviderError.permissionDenied("Calendar access was denied. Please enable in System Preferences > Privacy & Security > Calendars")
        case .authorized, .fullAccess, .writeOnly:
            break
        @unknown default:
            throw SourceProviderError.permissionDenied("Unknown authorization status")
        }
    }

    // MARK: - Private Methods

    private func createSourceItem(from event: EKEvent) -> SourceItem {
        var metadata = SourceItemMetadata()
        metadata.startDate = event.startDate
        metadata.endDate = event.endDate
        metadata.eventLocation = event.location
        metadata.isAllDay = event.isAllDay
        metadata.calendarName = event.calendar.title

        // Collect attendee names/emails
        if let attendees = event.attendees {
            metadata.attendees = attendees.compactMap { participant in
                if let name = participant.name {
                    return name
                }
                return participant.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
            }
        }

        // Build content string
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var content = ""
        if event.isAllDay {
            let dayFormatter = DateFormatter()
            dayFormatter.dateStyle = .medium
            dayFormatter.timeStyle = .none
            content += "All-day event: \(dayFormatter.string(from: event.startDate))\n"
        } else {
            content += "Time: \(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))\n"
        }
        if let location = event.location, !location.isEmpty {
            content += "Location: \(location)\n"
        }
        if let attendees = metadata.attendees, !attendees.isEmpty {
            content += "Attendees: \(attendees.joined(separator: ", "))\n"
        }
        if let notes = event.notes, !notes.isEmpty {
            content += "Notes: \(notes)"
        }

        return SourceItem(
            sourceType: .calendar,
            sourceName: name,
            title: event.title ?? "Untitled Event",
            content: content,
            metadata: metadata
        )
    }
}
