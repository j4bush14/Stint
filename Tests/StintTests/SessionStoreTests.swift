import Foundation
import Testing
@testable import Stint

@MainActor
@Suite("Session store")
struct SessionStoreTests {
    let env = TestEnvironment()

    private func session(title: String = "", tag: UUID? = nil, completed: Bool = true) -> Session {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        return Session(phase: .focus, title: title, tagID: tag, startedAt: start,
                       completedAt: completed ? start + 1500 : nil, duration: 1500)
    }

    @Test("Starts with three default tags")
    func defaultTags() {
        #expect(env.store.tags.map(\.title) == ["Deep Work", "Learning", "Errands"])
    }

    @Test("Saves sessions and tags to disk and loads them back")
    func persistence() {
        let saved = session(title: "Draft")
        env.store.upsert(saved)
        env.store.tags.append(Tag(title: "Reading", color: .sage, order: 3))

        let reloaded = SessionStore(directory: env.directory)
        #expect(reloaded.sessions == [saved])
        #expect(reloaded.tags.map(\.title).contains("Reading"))
    }

    @Test("Upserting an existing session replaces it")
    func upsertReplaces() {
        var item = session(title: "First")
        env.store.upsert(item)
        item.title = "Renamed"
        env.store.upsert(item)
        #expect(env.store.sessions.map(\.title) == ["Renamed"])
    }

    @Test("Deleting a tag untags its sessions")
    func deleteTagUntags() throws {
        let tag = try #require(env.store.tags.first)
        env.store.upsert(session(tag: tag.id))
        #expect(env.store.sessionCount(for: tag) == 1)

        env.store.deleteTag(tag)
        #expect(!env.store.tags.contains(tag))
        #expect(env.store.sessions.first?.tagID == nil)
    }

    @Test("Moving tags reorders them and renumbers their order")
    func moveTags() {
        let ids = env.store.tags.map(\.id)
        env.store.moveTags([ids[2]], before: ids[0])
        #expect(env.store.tags.map(\.id) == [ids[2], ids[0], ids[1]])
        #expect(env.store.tags.map(\.order) == [0, 1, 2])

        env.store.moveTags([ids[2]], before: nil)
        #expect(env.store.tags.map(\.id) == [ids[0], ids[1], ids[2]])
    }

    @Test("Saving an existing session updates it in place")
    func upsertUpdates() {
        var draft = session(title: "Draft")
        env.store.upsert(draft)
        draft.title = "Outline"
        env.store.upsert(draft)
        #expect(env.store.sessions.map(\.title) == ["Outline"])
    }

    @Test("Deleting one session, or all of them, sticks after reloading")
    func deleting() {
        let keep = session(title: "Keep")
        let drop = session(title: "Drop")
        env.store.upsert(keep)
        env.store.upsert(drop)

        env.store.delete(drop)
        #expect(env.store.sessions == [keep])
        #expect(SessionStore(directory: env.directory).sessions == [keep])

        env.store.deleteAll()
        #expect(env.store.sessions.isEmpty)
        #expect(SessionStore(directory: env.directory).sessions.isEmpty)
    }

    @Test("CSV export quotes fields and escapes embedded quotes")
    func csvEscaping() throws {
        env.store.upsert(session(title: #"Read "Dune", part 1"#))
        let lines = env.store.csv(for: env.store.sessions).split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].hasPrefix("Type,Title,Tag"))
        #expect(lines[1].contains(#""Read ""Dune"", part 1""#))
    }
}

@Suite("Session time")
struct SessionTimeTests {
    let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test("Focused time excludes pauses")
    func focusedTimeExcludesPauses() {
        let session = Session(
            phase: .focus, title: "", tagID: nil, startedAt: start,
            completedAt: start + 1800, duration: 1500,
            interruptions: [Interruption(startedAt: start + 600, finishedAt: start + 900)]
        )
        #expect(session.durationWithInterruptions == 1800)
        #expect(session.interruptedTime == 300)
        #expect(session.focusedTime == 1500)
    }

    @Test("An unfinished session ends where its last pause began")
    func unfinishedSession() {
        let session = Session(
            phase: .focus, title: "", tagID: nil, startedAt: start, completedAt: nil, duration: 1500,
            interruptions: [Interruption(startedAt: start + 400, finishedAt: nil)]
        )
        #expect(session.durationWithInterruptions == 400)
    }
}
