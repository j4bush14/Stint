import Foundation
import FoundationModels

/// `FocusCoach` backed by Apple Intelligence through Foundation Models. Runs entirely on
/// this Mac; when the model isn't available, callers fall back to static text.
struct OnDeviceCoach: FocusCoach {
    private static let instructions = """
        You are a calm, encouraging focus coach inside a Pomodoro timer app. \
        Be specific to the numbers you are given, warm but brief, and never invent data. \
        Write plain sentences with no markdown, lists or emoji.
        """

    var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            nil
        case .unavailable(.appleIntelligenceNotEnabled):
            "Turn on Apple Intelligence in System Settings to get summaries."
        case .unavailable(.modelNotReady):
            "The on-device model is still downloading. Try again later."
        case .unavailable(.deviceNotEligible):
            "This Mac doesn't support Apple Intelligence."
        case .unavailable:
            "Apple Intelligence isn't available right now."
        }
    }

    func summary(of sessions: [Session], periodName: String, tags: [Tag]) -> AsyncThrowingStream<String, Error> {
        let prompt = """
            Here is my focus data for \(periodName):
            \(SummaryPrompt.describe(sessions, tags: tags))

            In two or three sentences, tell me how my focus went and give one concrete, \
            practical suggestion for the next period.
            """
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let session = LanguageModelSession(instructions: Self.instructions)
                    for try await snapshot in session.streamResponse(to: prompt) {
                        continuation.yield(snapshot.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func encouragement(afterFocusTitled title: String, minutes: Int, completedToday: Int) async -> String? {
        guard isAvailable else { return nil }
        let prompt = """
            I just finished a \(minutes)-minute focus session\(title.isEmpty ? "" : " on \"\(title)\""). \
            It's my \(Self.ordinal(completedToday)) completed session today. \
            Write one short, upbeat sentence (under 18 words) congratulating me and nudging me to take my break.
            """
        // Notifications shouldn't wait on the model: give up after a few seconds.
        return await withTaskGroup(of: String?.self) { group in
            group.addTask {
                let session = LanguageModelSession(instructions: Self.instructions)
                return try? await session.respond(to: prompt).content
                    .trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"")))
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(6))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private static func ordinal(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
