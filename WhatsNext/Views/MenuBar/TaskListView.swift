import SwiftUI

// MARK: - Task List View

struct TaskListView: View {
    let tasks: [SuggestedTask]
    let onExecute: (SuggestedTask) -> Void
    let onDismiss: (SuggestedTask) -> Void
    let onComplete: (SuggestedTask) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(tasks) { task in
                    TaskRowView(
                        task: task,
                        onExecute: { onExecute(task) },
                        onDismiss: { onDismiss(task) },
                        onComplete: { onComplete(task) }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 600)
    }
}

// MARK: - Preview

#Preview {
    TaskListView(
        tasks: [
            SuggestedTask(
                title: "Complete user authentication",
                description: "Found TODO in auth.swift that needs implementation",
                priority: .high,
                estimatedMinutes: 45
            ),
            SuggestedTask(
                title: "Review pull request #123",
                description: "PR has been open for 3 days",
                priority: .medium,
                estimatedMinutes: 20
            ),
            SuggestedTask(
                title: "Update documentation",
                description: "README is out of date",
                priority: .low,
                estimatedMinutes: 15
            )
        ],
        onExecute: { _ in },
        onDismiss: { _ in },
        onComplete: { _ in }
    )
    .frame(width: 350)
}
