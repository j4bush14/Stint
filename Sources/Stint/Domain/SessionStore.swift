import Combine
import Foundation

/// Persists sessions and tags as JSON in Application Support.
@MainActor
final class SessionStore: ObservableObject {
    /// Where the app keeps its data: ~/Library/Application Support/Stint.
    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Stint", isDirectory: true)
    }

    @Published private(set) var sessions: [Session] = []
    @Published var tags: [Tag] = [] { didSet { saveTags() } }

    let directory: URL
    private var sessionsURL: URL { directory.appendingPathComponent("sessions.json") }
    private var tagsURL: URL { directory.appendingPathComponent("tags.json") }

    /// - Parameter directory: where `sessions.json` and `tags.json` live (tests use a temp folder).
    init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
    }

    // MARK: Sessions

    func upsert(_ session: Session) {
        if let i = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[i] = session
        } else {
            sessions.append(session)
        }
        saveSessions()
    }

    func delete(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        saveSessions()
    }

    func deleteAll() {
        sessions.removeAll()
        saveSessions()
    }

    func tag(for id: UUID?) -> Tag? {
        guard let id else { return nil }
        return tags.first { $0.id == id }
    }

    func sessionCount(for tag: Tag) -> Int {
        sessions.filter { $0.tagID == tag.id }.count
    }

    /// Moves the given tags in front of `target` (or to the end) and renumbers their order.
    func moveTags(_ ids: [UUID], before target: UUID?) {
        let moving = tags.filter { ids.contains($0.id) }
        var rest = tags.filter { !ids.contains($0.id) }
        let index = target.flatMap { t in rest.firstIndex { $0.id == t } } ?? rest.endIndex
        rest.insert(contentsOf: moving, at: index)
        for i in rest.indices { rest[i].order = i }
        tags = rest
    }

    func deleteTag(_ tag: Tag) {
        tags.removeAll { $0.id == tag.id }
        for i in sessions.indices where sessions[i].tagID == tag.id {
            sessions[i].tagID = nil
        }
        saveSessions()
    }

    // MARK: Export

    func csv(for list: [Session]) -> String {
        let iso = ISO8601DateFormatter()
        var rows = ["Type,Title,Tag,Started,Completed,Planned Minutes,Focused Minutes,Interruptions"]
        for s in list.sorted(by: { $0.startedAt < $1.startedAt }) {
            let fields: [String] = [
                s.phase.title,
                s.title,
                tag(for: s.tagID)?.title ?? "",
                iso.string(from: s.startedAt),
                s.completedAt.map(iso.string(from:)) ?? "",
                String(format: "%.1f", s.duration / 60),
                String(format: "%.1f", s.focusedTime / 60),
                "\(s.interruptions.count)",
            ]
            rows.append(fields.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    // MARK: Persistence

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: sessionsURL),
           let list = try? decoder.decode([Session].self, from: data) {
            sessions = list
        }
        if let data = try? Data(contentsOf: tagsURL),
           let list = try? decoder.decode([Tag].self, from: data) {
            tags = list
        } else {
            tags = [
                Tag(title: "Deep Work", color: .sky, order: 0),
                Tag(title: "Learning", color: .violet, order: 1),
                Tag(title: "Errands", color: .amber, order: 2),
            ]
        }
    }

    private func saveSessions() {
        write(sessions, to: sessionsURL)
    }

    private func saveTags() {
        write(tags, to: tagsURL)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            NSLog("Stint: failed to save \(url.lastPathComponent): \(error)")
        }
    }
}
