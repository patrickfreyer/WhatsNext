import SwiftUI

// MARK: - Task Row View

struct TaskRowView: View {
    let task: SuggestedTask
    let onExecute: () -> Void
    let onDismiss: () -> Void

    @State private var isHovered = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main row
            HStack(alignment: .top, spacing: 10) {
                // Priority indicator
                priorityIndicator

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(isExpanded ? nil : 2)

                    HStack(spacing: 8) {
                        // Source info
                        if let sourceInfo = task.sourceInfo {
                            Label(sourceInfo.sourceName, systemImage: sourceInfo.sourceType.iconName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        // Time estimate
                        if let minutes = task.estimatedMinutes {
                            Label("\(minutes)m", systemImage: "clock")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Action buttons
                if isHovered || isExpanded {
                    actionButtons
                }
            }

            // Expanded content
            if isExpanded {
                expandedContent
            }
        }
        .padding(10)
        .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    // MARK: - Subviews

    private var priorityIndicator: some View {
        Circle()
            .fill(priorityColor)
            .frame(width: 8, height: 8)
            .padding(.top, 5)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 4) {
            Button(action: onExecute) {
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
            }
            .buttonStyle(.bordered)
            .tint(.accentColor)
            .help("Execute in Claude Code")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
            }
            .buttonStyle(.bordered)
            .help("Dismiss task")
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Description
            Text(task.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Action plan
            if !task.actionPlan.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Action Plan")
                        .font(.caption)
                        .fontWeight(.semibold)

                    ForEach(task.actionPlan) { step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(step.stepNumber).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 16, alignment: .trailing)

                            Text(step.description)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if step.command != nil {
                                Image(systemName: "terminal")
                                    .font(.caption2)
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }

            // File location
            if let sourceInfo = task.sourceInfo,
               let filePath = sourceInfo.filePath {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                    Text(filePath)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let line = sourceInfo.lineNumber {
                        Text(":\(line)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Execute button
            Button(action: onExecute) {
                HStack {
                    Image(systemName: "terminal")
                    Text("Execute in Claude Code")
                }
                .font(.caption)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 4)
        .padding(.leading, 18)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        TaskRowView(
            task: SuggestedTask(
                title: "Complete user authentication implementation",
                description: "Found TODO in auth.swift on line 45 that needs OAuth implementation",
                priority: .high,
                estimatedMinutes: 45,
                actionPlan: [
                    ActionStep(stepNumber: 1, description: "Review existing auth code", command: nil),
                    ActionStep(stepNumber: 2, description: "Implement OAuth flow", command: "claude 'implement OAuth'"),
                    ActionStep(stepNumber: 3, description: "Add unit tests", command: nil)
                ],
                sourceInfo: SourceInfo(
                    sourceType: .folder,
                    sourceName: "MyProject",
                    filePath: "src/auth/AuthService.swift",
                    lineNumber: 45
                )
            ),
            onExecute: {},
            onDismiss: {}
        )

        TaskRowView(
            task: SuggestedTask(
                title: "Reply to email from John",
                description: "Urgent email about project deadline",
                priority: .medium,
                sourceInfo: SourceInfo(sourceType: .mail, sourceName: "Mail")
            ),
            onExecute: {},
            onDismiss: {}
        )
    }
    .padding()
    .frame(width: 350)
}
