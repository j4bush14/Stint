import SwiftUI

/// A short, on-device written summary of the selected period.
struct SummaryCard: View {
    @Environment(\.focusCoach) private var coach
    let sessions: [Session]
    let periodName: String
    let tags: [Tag]

    @State private var text = ""
    @State private var isWorking = false
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Summary").font(.headline)
                Spacer()
                if isWorking {
                    ProgressView().controlSize(.small)
                }
                if coach.isAvailable {
                    Button(text.isEmpty ? "Summarize" : "Summarize Again", action: run)
                        .disabled(isWorking || sessions.isEmpty)
                        .testTarget("summary.run")
                }
            }
            if let reason = coach.unavailableReason {
                Text(reason).font(.callout).foregroundStyle(.secondary)
            } else if sessions.isEmpty {
                Text("Nothing recorded in this period yet.").font(.callout).foregroundStyle(.secondary)
            } else if failed {
                Text("Couldn't write a summary this time. Try again in a moment.").font(.callout).foregroundStyle(.secondary)
            } else if text.isEmpty {
                Text("A short written summary of this period, generated on this Mac by Apple Intelligence.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text(text)
                    .font(.callout)
                    .textSelection(.enabled)
                    .contentTransition(.opacity)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .testTarget("summary", value: failed ? "failed" : text)
    }

    private func run() {
        isWorking = true
        failed = false
        text = ""
        Task {
            do {
                for try await partial in coach.summary(of: sessions, periodName: periodName, tags: tags) {
                    withAnimation(.smooth) { text = partial }
                }
            } catch {
                failed = true
            }
            isWorking = false
        }
    }
}
