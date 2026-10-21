import AppKit
import UserNotifications

/// What the user chose on a notification.
enum NotificationAction {
    case startNext, skip, open
}

/// Sounds and notifications for finished sessions and blocked apps.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private let settings: AppSettings
    private let store: SessionStore
    private let coach: any FocusCoach
    private let onAction: (NotificationAction) -> Void
    private let center = UNUserNotificationCenter.current()
    private let categoryID = "phaseCompleted"

    init(settings: AppSettings, store: SessionStore, coach: any FocusCoach,
         onAction: @escaping (NotificationAction) -> Void) {
        self.settings = settings
        self.store = store
        self.coach = coach
        self.onAction = onAction
        super.init()
    }

    func start() {
        center.delegate = self
        let start = UNNotificationAction(identifier: "start", title: "Start Next")
        let skip = UNNotificationAction(identifier: "skip", title: "Skip It")
        center.setNotificationCategories([
            UNNotificationCategory(identifier: categoryID, actions: [start, skip], intentIdentifiers: []),
        ])
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func phaseCompleted(_ session: Session, next: Phase) {
        Sounds.play(session.phase == .focus ? settings.focusCompleteSound : settings.breakCompleteSound,
                    volume: settings.notificationsVolume)
        guard settings.allowNotifications else { return }

        let content = UNMutableNotificationContent()
        content.categoryIdentifier = categoryID
        content.userInfo = ["next": next.rawValue]
        content.interruptionLevel = .timeSensitive

        guard session.phase == .focus else {
            content.title = "Break's over"
            content.body = "Ready when you are."
            post(content)
            return
        }

        content.title = session.title.isEmpty ? "Focus session done" : "Done: \(session.title)"
        switch settings.notificationMessage {
        case .none:
            content.body = "Time for a break."
        case .quote:
            content.body = Quotes.random()
        case .encouragement where !coach.isAvailable:
            content.body = Quotes.random()
        case .encouragement:
            // Ask the coach for a personal line; fall back to a quote if it's slow or fails.
            let doneToday = store.sessions.filter {
                $0.phase == .focus && $0.isCompleted && Calendar.current.isDateInToday($0.startedAt)
            }.count
            let coach = coach
            Task {
                let line = await coach.encouragement(afterFocusTitled: session.title,
                                                     minutes: Int(session.duration / 60),
                                                     completedToday: max(1, doneToday))
                content.body = line ?? Quotes.random()
                self.post(content)
            }
            return
        }
        post(content)
    }

    func blocked(appName: String) {
        guard settings.allowNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(appName) is paused for now"
        content.body = "It's on your blocking list until this focus session ends."
        center.add(UNNotificationRequest(identifier: "blocked-\(appName)", content: content, trigger: nil))
    }

    private func post(_ content: UNNotificationContent) {
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    // The notification center calls its delegate on an arbitrary queue.

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action: NotificationAction = switch response.actionIdentifier {
        case "start": .startNext
        case "skip": .skip
        default: .open
        }
        await MainActor.run { onAction(action) }
    }
}
