import SwiftUI

// MARK: - Prompt Settings View

struct PromptSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Model Selection
            Section {
                Text("Claude Model")
                    .font(.headline)

                Picker("Model", selection: $viewModel.claude.modelName) {
                    Text("Claude Sonnet").tag("claude-sonnet-4-20250514")
                    Text("Claude Opus").tag("claude-opus-4-0-20250514")
                    Text("Claude Haiku").tag("claude-haiku")
                }
                .pickerStyle(.segmented)

                Text("Sonnet is recommended for best balance of speed and quality")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Max Tokens
            Section {
                Text("Response Settings")
                    .font(.headline)

                Stepper(
                    "Max tokens: \(viewModel.claude.maxTokens)",
                    value: $viewModel.claude.maxTokens,
                    in: 1024...8192,
                    step: 512
                )

                Text("Higher values allow longer responses but may take more time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // System Prompt
            Section {
                HStack {
                    Text("System Prompt")
                        .font(.headline)

                    Spacer()

                    Button("Reset to Default") {
                        viewModel.claude.systemPrompt = ClaudeConfiguration.default.systemPrompt
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }

                TextEditor(text: $viewModel.claude.systemPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .border(Color.secondary.opacity(0.3))

                Text("The system prompt instructs Claude how to analyze your sources and suggest tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Save Button
            HStack {
                Spacer()

                Button("Save Changes") {
                    viewModel.saveClaude()
                }
                .buttonStyle(.borderedProminent)

                if viewModel.showingSaveConfirmation {
                    Text("Saved!")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}

#Preview {
    PromptSettingsView(viewModel: SettingsViewModel())
}
