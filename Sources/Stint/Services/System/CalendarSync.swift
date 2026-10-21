import EventKit
import Foundation

/// Writes finished focus sessions to a calendar of the user's choice.
@MainActor
final class CalendarSync: ObservableObject {
    @Published private(set) var calendars: [EKCalendar] = []
    @Published private(set) var authorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess

    private let eventStore = EKEventStore()
    private let settings: AppSettings
    private let store: SessionStore

    init(settings: AppSettings, store: SessionStore) {
        self.settings = settings
        self.store = store
    }

    func requestAccess() {
        eventStore.requestFullAccessToEvents { granted, _ in
            Task { @MainActor in
                self.authorized = granted
                self.reloadCalendars()
                if !granted { self.settings.syncWithCalendar = false }
            }
        }
    }

    func reloadCalendars() {
        guard authorized else { calendars = []; return }
        calendars = eventStore.calendars(for: .event).filter { $0.allowsContentModifications }
    }

    func add(_ session: Session) {
        guard settings.syncWithCalendar, authorized, session.phase == .focus,
              let end = session.completedAt else { return }
        guard let calendar = eventStore.calendar(withIdentifier: settings.calendarIdentifier)
            ?? eventStore.defaultCalendarForNewEvents else { return }
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = session.title.isEmpty ? "Focus" : session.title
        event.startDate = session.startedAt
        event.endDate = end
        if let tag = store.tag(for: session.tagID) { event.notes = "Tag: \(tag.title)" }
        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            NSLog("Stint: calendar save failed: \(error)")
        }
    }
}
