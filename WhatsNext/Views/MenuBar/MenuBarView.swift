import SwiftUI

// MARK: - Menu Bar View

struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView

            Divider()

            // Task List or Empty State
            if viewModel.isRefreshing && viewModel.tasks.isEmpty {
                loadingView
            } else if viewModel.tasks.isEmpty {
                emptyStateView
            } else {
                TaskListView(
                    tasks: viewModel.displayedTasks,
                    onExecute: viewModel.executeTask,
                    onDismiss: viewModel.dismissTask
                )

                if viewModel.hasMoreTasks {
                    moreTasksView
                }
            }

            Divider()

            // Footer
            footerView
        }
        .frame(width: 350)
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text("What's Next")
                .font(.headline)

            Spacer()

            if viewModel.isRefreshing {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }

            Button(action: {
                Task {
                    await viewModel.refresh()
                }
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isRefreshing)
            .help("Refresh tasks")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Analyzing sources...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.green)

            Text("All caught up!")
                .font(.headline)

            Text("No tasks to suggest right now")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Refresh") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var moreTasksView: some View {
        HStack {
            Spacer()
            Text("\(viewModel.tasks.count - viewModel.maxTasksToShow) more tasks")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
    }

    private var footerView: some View {
        HStack {
            if let date = viewModel.lastRefreshDate {
                Text("Updated \(date.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Menu {
                SettingsLink {
                    Text("Settings...")
                }

                Divider()

                Button("Clear All Tasks") {
                    viewModel.clearAllTasks()
                }

                Divider()

                Button("Quit") {
                    viewModel.quit()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Error Banner

private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)

            Text(message)
                .font(.caption)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color.yellow.opacity(0.2))
        .cornerRadius(6)
        .padding(.horizontal)
        .padding(.top, 4)
    }
}

#Preview {
    MenuBarView(viewModel: MenuBarViewModel())
}
