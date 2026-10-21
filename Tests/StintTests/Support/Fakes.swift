import Foundation
@testable import Stint

/// A coach that answers instantly with fixed text.
struct FakeCoach: FocusCoach {
    var isAvailable = true
    var unavailableReason: String? = nil
    var summaryParts = ["You focused", "You focused well this week."]
    var fails = false

    func summary(of sessions: [Session], periodName: String, tags: [Tag]) -> AsyncThrowingStream<String, Error> {
        let parts = summaryParts
        let fails = fails
        return AsyncThrowingStream { continuation in
            for part in parts { continuation.yield(part) }
            if fails {
                continuation.finish(throwing: CocoaError(.featureUnsupported))
            } else {
                continuation.finish()
            }
        }
    }

    func encouragement(afterFocusTitled title: String, minutes: Int, completedToday: Int) async -> String? {
        "Nice work."
    }
}

/// File dialogs that "choose" preset answers and record what was asked.
@MainActor
final class FakeFileDialogs: FileDialogs {
    var applications: [URL] = []
    var csvDestination: URL?
    private(set) var askedForApplications = 0
    private(set) var suggestedCSVName: String?

    func chooseApplications() -> [URL] {
        askedForApplications += 1
        return applications
    }

    func chooseCSVDestination(suggestedName: String) -> URL? {
        suggestedCSVName = suggestedName
        return csvDestination
    }
}
