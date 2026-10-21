import Foundation
import Testing
@testable import Stint

@MainActor
@Suite("Focus timer")
struct FocusTimerTests {
    let env = TestEnvironment()

    // MARK: Basics

    @Test("Starts idle in the first focus session")
    func initialState() {
        let timer = env.makeTimer()
        #expect(timer.phase == .focus)
        #expect(!timer.isRunning)
        #expect(!timer.hasStarted)
        #expect(timer.completedFocus == 0)
        #expect(timer.remaining == 25 * 60)
        #expect(timer.progress == 0)
    }

    @Test("Counts down from the clock while running")
    func countsDown() {
        let timer = env.makeTimer()
        timer.start()
        env.run(timer, for: 90)
        #expect(timer.remaining == 25 * 60 - 90)
        #expect(abs(timer.progress - 90.0 / 1500) < 0.0001)
    }

    @Test("Pausing freezes the time and records an interruption")
    func pauseAndResume() throws {
        let timer = env.makeTimer()
        timer.start()
        env.run(timer, for: 60)
        #expect(timer.pause())
        env.clock.advance(300) // time passes while paused
        #expect(timer.remaining == 24 * 60)

        timer.start()
        env.run(timer, for: 60)
        #expect(timer.remaining == 23 * 60)

        let session = try #require(timer.currentSession)
        #expect(session.interruptions.count == 1)
        #expect(session.interruptions[0].finishedAt != nil)
    }

    @Test("Idle length follows settings, but a running session keeps its length")
    func lengthFollowsSettingsUntilStarted() {
        let timer = env.makeTimer()
        env.settings.focusMinutes = 40
        #expect(timer.remaining == 40 * 60)

        timer.start()
        env.settings.focusMinutes = 10
        #expect(timer.phaseLength == 40 * 60)
    }

    // MARK: Cycle

    @Test("Finishing a focus session records it and starts the short break")
    func completesFocus() throws {
        var completed: [Session] = []
        let timer = env.makeTimer()
        timer.onPhaseCompleted = { completed.append($0) }
        timer.title = "Write tests"

        timer.start()
        env.run(timer, for: 25 * 60)

        #expect(timer.phase == .shortBreak)
        #expect(timer.completedFocus == 1)
        #expect(timer.isRunning, "breaks start automatically by default")
        let saved = try #require(env.store.sessions.first)
        #expect(saved.isCompleted)
        #expect(saved.title == "Write tests")
        #expect(completed.map(\.id) == [saved.id])
    }

    @Test("Focus sessions don't auto-start unless enabled")
    func focusAutoStartIsOptIn() {
        let timer = env.makeTimer()
        timer.start()
        env.run(timer, for: 25 * 60)
        env.run(timer, for: 5 * 60)
        #expect(timer.phase == .focus)
        #expect(!timer.isRunning)

        env.settings.startFocusAutomatically = true
        timer.start()
        env.run(timer, for: 25 * 60)
        env.run(timer, for: 5 * 60)
        #expect(timer.isRunning)
    }

    @Test("A long break follows the last focus session of the cycle")
    func longBreakAfterCycle() {
        env.settings.cycle = 2
        let timer = env.makeTimer()

        timer.start(); env.run(timer, for: 25 * 60)   // focus 1 → short break (auto-starts)
        env.run(timer, for: 5 * 60)                   // short break → focus 2
        timer.start(); env.run(timer, for: 25 * 60)   // focus 2 → long break

        #expect(timer.phase == .longBreak)
        #expect(timer.remaining == 15 * 60)

        env.run(timer, for: 15 * 60)
        #expect(timer.phase == .focus)
        #expect(timer.completedFocus == 0)
    }

    // MARK: Skip, stop, rewind

    @Test("Skipping moves on without completing the session")
    func skip() throws {
        let timer = env.makeTimer()
        timer.start()
        env.run(timer, for: 120)
        #expect(timer.skip())

        #expect(timer.phase == .shortBreak)
        #expect(timer.completedFocus == 1)
        #expect(!timer.isRunning)
        let saved = try #require(env.store.sessions.first)
        #expect(!saved.isCompleted)
    }

    @Test("Very short abandoned sessions aren't recorded")
    func ignoresAccidentalStarts() {
        let timer = env.makeTimer()
        timer.start()
        env.run(timer, for: 3)
        timer.stop()
        #expect(env.store.sessions.isEmpty)
        #expect(timer.remaining == 25 * 60)
    }

    @Test("Rewind restarts a session that has begun")
    func rewindRestarts() {
        let timer = env.makeTimer()
        timer.start()
        env.run(timer, for: 300)
        #expect(timer.previous())
        #expect(timer.phase == .focus)
        #expect(!timer.hasStarted)
        #expect(timer.remaining == 25 * 60)
    }

    @Test("Rewind steps back through the cycle and stops at its start")
    func rewindStepsBack() {
        let timer = env.makeTimer()
        #expect(!timer.previous(), "nothing before the first focus session")

        timer.skip()                       // → short break, 1 done
        #expect(timer.previous())          // → focus 1 again
        #expect(timer.phase == .focus)
        #expect(timer.completedFocus == 0)

        timer.skip(); timer.skip()         // → focus 2
        #expect(timer.previous())          // → the short break before it
        #expect(timer.phase == .shortBreak)
        #expect(timer.completedFocus == 1)
    }

    @Test("Starting a new cycle returns to the first focus session")
    func resetCycle() {
        let timer = env.makeTimer()
        timer.skip(); timer.skip(); timer.skip()
        #expect(timer.resetCycle())
        #expect(timer.phase == .focus)
        #expect(timer.completedFocus == 0)
    }

    // MARK: Lock-In

    @Test("Lock-In blocks pause, skip, stop and rewind while focusing")
    func lockIn() {
        env.settings.lockIn = true
        let timer = env.makeTimer()
        timer.start()
        #expect(timer.isLocked)
        #expect(!timer.pause())
        #expect(!timer.skip())
        #expect(!timer.stop())
        #expect(!timer.previous())
        #expect(!timer.setTimeLeft(60))
        #expect(timer.isRunning)
    }

    @Test("Lock-In doesn't apply to breaks")
    func lockInBreaksStayFlexible() {
        env.settings.lockIn = true
        let timer = env.makeTimer()
        timer.start()
        env.run(timer, for: 25 * 60)
        #expect(timer.phase == .shortBreak)
        #expect(!timer.isLocked)
        #expect(timer.pause())
    }

    // MARK: Typed time

    @Test("Typing a time sets what's left and keeps time already spent")
    func setTimeLeft() throws {
        let timer = env.makeTimer()
        timer.start()
        env.run(timer, for: 600)
        #expect(timer.setTimeLeft(5 * 60))

        #expect(timer.remaining == 5 * 60)
        #expect(timer.phaseLength == 15 * 60)
        #expect(abs(timer.progress - 10.0 / 15) < 0.0001)
        #expect(try #require(timer.currentSession).duration == 15 * 60)
    }

    @Test("A typed time applies to the next start and ends with the phase")
    func typedTimeIsOneOff() {
        let timer = env.makeTimer()
        timer.setTimeLeft(45 * 60)
        timer.start()
        env.run(timer, for: 45 * 60)
        #expect(timer.phase == .shortBreak)
        #expect(timer.remaining == 5 * 60)
    }

    // MARK: Tags

    @Test("A tag with its own timer overrides lengths and cycle")
    func tagPreset() {
        var preset = TagPreset()
        preset.focusMinutes = 50
        preset.shortBreakMinutes = 10
        preset.cycle = 2
        let tag = Tag(title: "Deep", color: .sky, order: 0, isPresetEnabled: true, preset: preset)
        env.store.tags = [tag]

        let timer = env.makeTimer()
        timer.selectedTagID = tag.id
        #expect(timer.remaining == 50 * 60)
        #expect(timer.cycle == 2)

        timer.start()
        env.run(timer, for: 50 * 60)
        #expect(timer.remaining == 10 * 60)
        #expect(env.store.sessions.first?.tagID == tag.id)
    }

    // MARK: Persistence

    @Test("The cycle position survives a relaunch")
    func restoresCyclePosition() {
        let first = env.makeTimer()
        first.skip(); first.skip(); first.skip() // focus 2 done → short break, 2 done
        #expect(first.phase == .shortBreak)

        let relaunched = env.makeTimer()
        #expect(relaunched.phase == .shortBreak)
        #expect(relaunched.completedFocus == 2)
    }

    @Test("A fresh cycle at launch ignores the saved position")
    func freshCycleAtLaunch() {
        env.makeTimer().skip()
        env.settings.resetCycleAtLaunch = true
        let relaunched = env.makeTimer()
        #expect(relaunched.phase == .focus)
        #expect(relaunched.completedFocus == 0)
    }

    // MARK: Hooks

    @Test("Reports each whole second while running")
    func secondHook() {
        var seconds = 0
        let timer = env.makeTimer()
        timer.onSecond = { seconds += 1 }
        timer.start()
        for _ in 0..<3 { env.run(timer, for: 1) }
        env.run(timer, for: 0.4) // same second: no extra report
        #expect(seconds == 3)
    }
}

@MainActor
@Suite("Picking a time")
struct TimeEditingTests {
    let env = TestEnvironment()

    @Test("The timer can't start while a time is being picked")
    func holdsWhileEditing() {
        let timer = env.makeTimer()
        #expect(timer.beginEditingTime())
        timer.start()
        #expect(!timer.isRunning)
        #expect(!timer.hasStarted)

        timer.commitTimeEdit()
        timer.start()
        #expect(timer.isRunning)
    }

    @Test("The draft starts at the time left and the commit applies it")
    func commit() {
        let timer = env.makeTimer()
        timer.beginEditingTime()
        #expect(timer.timeDraft == 25 * 60)
        timer.setTimeDraft(40 * 60)
        timer.commitTimeEdit()
        #expect(!timer.isEditingTime)
        #expect(timer.remaining == 40 * 60)
    }

    @Test("Cancelling leaves the time unchanged")
    func cancel() {
        let timer = env.makeTimer()
        timer.beginEditingTime()
        timer.setTimeDraft(5 * 60)
        timer.cancelTimeEdit()
        #expect(!timer.isEditingTime)
        #expect(timer.remaining == 25 * 60)
    }

    @Test("A running timer is held while editing and resumes afterwards, without logging a pause")
    func pausesAndResumes() throws {
        let timer = env.makeTimer()
        timer.start()
        env.run(timer, for: 60)
        timer.beginEditingTime()
        #expect(!timer.isRunning)
        env.clock.advance(120) // time spent picking doesn't count
        #expect(timer.remaining == 24 * 60)

        timer.setTimeDraft(10 * 60)
        timer.commitTimeEdit()
        #expect(timer.isRunning)
        #expect(timer.remaining == 10 * 60)
        #expect(try #require(timer.currentSession).interruptions.isEmpty)
    }

    @Test("The draft stays between one second and 23:59:59", arguments: [
        (-30, 1), (0, 1), (90, 90), (100_000, FocusTimer.maximumTime),
    ] as [(Double, Double)])
    func clamps(input: Double, expected: Double) {
        let timer = env.makeTimer()
        timer.beginEditingTime()
        timer.setTimeDraft(input)
        #expect(timer.timeDraft == expected)
    }

    @Test("Lock-In prevents changing the time of a running focus session")
    func lockIn() {
        env.settings.lockIn = true
        let timer = env.makeTimer()
        timer.start()
        #expect(!timer.beginEditingTime())
    }

    @Test("Changing phase ends editing")
    func phaseChangeEndsEditing() {
        let timer = env.makeTimer()
        timer.beginEditingTime()
        timer.skip()
        #expect(!timer.isEditingTime)
    }
}
