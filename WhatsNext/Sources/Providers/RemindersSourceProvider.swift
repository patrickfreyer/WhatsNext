import EventKit
import Foundation

// MARK: - Reminders Source Provider

/// Provider for fetching reminders from Apple Reminders
final class RemindersSourceProvider: SourceProvider {
    let id = UUID()
    var name: String = "Reminders"
    let sourceType: SourceType = .reminders
    var isEnabled: Bool

    private let configuration: RemindersSourceConfiguration
    private let eventStore = EKEventStore()

    init(configuration: RemindersSourceConfiguration) {
        self.isEnabled = configuration.isEnabled
        self.configuration = configuration
    }

    // MARK: - SourceProvider

    func fetchItems() async throws -> [SourceItem] {
        // Check authorization
        guard await checkPermissions() else {
            throw SourceProviderError.permissionDenied("Reminders access not granted")
        }

        var items: [SourceItem] = []

        // Get calendars (reminder lists)
        let calendars: [EKCalendar]
        if let listNames = configuration.listNames, !listNames.isEmpty {
            calendars = eventStore.calendars(for: .reminder).filter { listNames.contains($0.title) }
        } else {
            calendars = eventStore.calendars(for: .reminder)
        }

        // Fetch reminders from each calendar
        for calendar in calendars {
            let predicate = eventStore.predicateForReminders(in: [calendar])

            let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
                eventStore.fetchReminders(matching: predicate) { reminders in
                    continuation.resume(returning: reminders ?? [])
                }
            }

            for reminder in reminders {
                // Skip completed if not including them
                if !configuration.includeCompleted && reminder.isCompleted {
                    continue
                }

                let item = createSourceItem(from: reminder, listName: calendar.title)
                items.append(item)
            }
        }

        // Sort by due date (soonest first), then by priority
        items.sort { item1, item2 in
            if let due1 = item1.metadata.dueDate, let due2 = item2.metadata.dueDate {
                return due1 < due2
            } else if item1.metadata.dueDate != nil {
                return true
            } else if item2.metadata.dueDate != nil {
                return false
            }
            return (item1.metadata.reminderPriority ?? 0) > (item2.metadata.reminderPriority ?? 0)
        }

        return items
    }

    func validateConfiguration() -> Bool {
        return true // Configuration is always valid for reminders
    }

    func checkPermissions() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)

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
        let status = EKEventStore.authorizationStatus(for: .reminder)

        switch status {
        case .notDetermined:
            // Request access
            if #available(macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToReminders()
                if !granted {
                    throw SourceProviderError.permissionDenied("Reminders access was denied")
                }
            } else {
                let granted = try await eventStore.requestAccess(to: .reminder)
                if !granted {
                    throw SourceProviderError.permissionDenied("Reminders access was denied")
                }
            }
        case .restricted:
            throw SourceProviderError.permissionDenied("Reminders access is restricted on this device")
        case .denied:
            throw SourceProviderError.permissionDenied("Reminders access was denied. Please enable in System Preferences > Privacy & Security > Reminders")
        case .authorized, .fullAccess, .writeOnly:
            // Already have some access
            break
        @unknown default:
            throw SourceProviderError.permissionDenied("Unknown authorization status")
        }
    }

    // MARK: - Private Methods

    private func createSourceItem(from reminder: EKReminder, listName: String) -> SourceItem {
        var metadata = SourceItemMetadata()
        metadata.dueDate = reminder.dueDateComponents?.date
        metadata.isCompleted = reminder.isCompleted
        metadata.reminderPriority = Int(reminder.priority)
        metadata.listName = listName

        var content = reminder.notes ?? ""
        if reminder.isCompleted {
            content = "[Completed] " + content
        }
        if let dueDate = metadata.dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            content = "Due: \(formatter.string(from: dueDate))\n" + content
        }

        return SourceItem(
            sourceType: .reminders,
            sourceName: name,
            title: reminder.title ?? "Untitled Reminder",
            content: content,
            metadata: metadata
        )
    }
}
