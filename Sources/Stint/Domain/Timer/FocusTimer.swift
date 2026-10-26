import Combine
import Foundation

/// The timer state machine.
///
/// A cycle is `cycle` focus sessions separated by short breaks, followed by a long break.
/// Time is tracked as *elapsed* time (banked running time plus the current run), and
/// everything else — remaining time, progress — is derived from it. That keeps pausing,
/// typed-in times and settings changes simple and exact.
@MainActor
final class FocusTimer: ObservableObject {
    /// Sessions shorter than this that are stopped or skipped aren't recorded.
    nonisolated static let minimumRecordedDuration: TimeInterval = 10

    @Published private(set) var phase: Phase = .focus
    @Published private(set) var isRunning = false
    /// Focus sessions finished (or skipped) in the current cycle.
    @Published private(set) var completedFocus = 0
    @Published var title = "" { didSet { currentSession?.title = title } }
    @Published var selectedTagID: UUID? { didSet { currentSession?.tagID = selectedTagID } }
    /// True while the user is picking a new time. The timer can't start until they finish.
    @Published private(set) var isEditingTime = false
    /// The time being picked, in seconds.
    @Published private(set) var timeDraft: TimeInterval = 0

    /// A phase finished on its own (not skipped or stopped).
    var onPhaseCompleted: ((Session) -> Void)?
    /// The timer started or resumed.
    var onStart: (() -> Void)?
    /// A new phase became current.
    var onPhaseChanged: ((Phase) -> Void)?
    /// Another whole second passed while running (drives the optional tick sound).
    var onSecond: (() -> Void)?

    private(set) var currentSession: Session?

    private let settings: AppSettings
    private let store: SessionStore
    private let state: UserDefaults
    private let now: () -> Date
    private let schedulesTicks: Bool

    /// Running time banked from earlier runs of the current phase.
    private var bankedTime: TimeInterval = 0
    /// When the current run started; nil while paused or idle.
    private var runStartedAt: Date?
    /// The current phase's length, fixed once it starts or when a time is typed in.
    private var fixedLength: TimeInterval?
    /// Whether to resume once time editing ends (the timer was running when it began).
    private var resumeAfterEditing = false
    private var ticker: Timer?
    private var lastWholeSecond = -1
    private var cancellables = Set<AnyCancellable>()

    private enum StateKey {
        static let phase = "state.phase"
        static let completedFocus = "state.completedFocus"
    }

    /// - Parameters:
    ///   - state: where the cycle position is remembered between launches.
    ///   - now: the clock; tests pass a controllable one.
    ///   - schedulesTicks: whether to drive `tick()` from a run-loop timer (tests tick manually).
    init(settings: AppSettings, store: SessionStore, state: UserDefaults,
         now: @escaping () -> Date = Date.init, schedulesTicks: Bool = true) {
        self.settings = settings
        self.store = store
        self.state = state
        self.now = now
        self.schedulesTicks = schedulesTicks

        if !settings.resetCycleAtLaunch,
           let saved = state.string(forKey: StateKey.phase).flatMap(Phase.init(rawValue:)) {
            phase = saved
            completedFocus = min(max(0, state.integer(forKey: StateKey.completedFocus)), cycle)
        }

        // Idle durations come from Settings, so settings changes are timer changes too.
        settings.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: Derived state

    var hasStarted: Bool { currentSession != nil }

    /// Whether `stop()` would change anything: a session is under way, or a custom time
    /// has been set for this phase.
    var canReset: Bool { hasStarted || fixedLength != nil }

    /// The selected tag's own timer settings, if it has them.
    var activePreset: TagPreset? {
        guard let tag = store.tag(for: selectedTagID), tag.isPresetEnabled else { return nil }
        return tag.preset
    }

    var cycle: Int { max(1, activePreset?.cycle ?? settings.cycle) }

    /// Which focus session of the cycle this is (or comes next), from 1: "2 of 4".
    var focusNumber: Int { min(completedFocus + 1, cycle) }

    func duration(of phase: Phase) -> TimeInterval {
        let minutes = switch phase {
        case .focus: activePreset?.focusMinutes ?? settings.focusMinutes
        case .shortBreak: activePreset?.shortBreakMinutes ?? settings.shortBreakMinutes
        case .longBreak: activePreset?.longBreakMinutes ?? settings.longBreakMinutes
        }
        return TimeInterval(max(1, minutes) * 60)
    }

    /// Length of the current phase.
    var phaseLength: TimeInterval { fixedLength ?? duration(of: phase) }

    var elapsed: TimeInterval {
        bankedTime + (runStartedAt.map { now().timeIntervalSince($0) } ?? 0)
    }

    var remaining: TimeInterval { max(0, phaseLength - elapsed) }

    var progress: Double { min(1, elapsed / phaseLength) }

    /// A focus session is actively counting down (blocking applies only then).
    var isFocusing: Bool { phase == .focus && isRunning }

    /// Lock-In blocks pausing, skipping and restarting while a focus session runs.
    var isLocked: Bool { settings.lockIn && phase == .focus && isRunning }

    // MARK: Commands

    func start() {
        guard !isRunning, !isEditingTime else { return }
        let date = now()
        if currentSession == nil {
            fixedLength = phaseLength
            currentSession = Session(phase: phase, title: title, tagID: selectedTagID,
                                     startedAt: date, duration: phaseLength)
        } else {
            closeOpenInterruption(at: date)
        }
        runStartedAt = date
        isRunning = true
        startTicker()
        onStart?()
    }

    @discardableResult
    func pause() -> Bool {
        guard isRunning, !isLocked else { return false }
        bankedTime = elapsed
        runStartedAt = nil
        isRunning = false
        stopTicker()
        currentSession?.interruptions.append(Interruption(startedAt: now()))
        return true
    }

    func toggle() {
        if isRunning { pause() } else { start() }
    }

    /// Sets the time left in the current phase. Time already spent counts toward the
    /// new length, so progress stays continuous.
    @discardableResult
    func setTimeLeft(_ seconds: TimeInterval) -> Bool {
        guard !isLocked, seconds >= 1 else { return false }
        objectWillChange.send()
        let length = elapsed + seconds
        fixedLength = length
        currentSession?.duration = length
        return true
    }

    // MARK: Editing the time

    /// The longest time that can be set.
    nonisolated static let maximumTime: TimeInterval = 24 * 60 * 60 - 1

    /// Holds the timer while a new time is picked. A running timer is paused without
    /// recording an interruption and resumes when editing ends.
    @discardableResult
    func beginEditingTime() -> Bool {
        guard !isLocked, !isEditingTime else { return false }
        if isRunning {
            bankedTime = elapsed
            runStartedAt = nil
            isRunning = false
            stopTicker()
            resumeAfterEditing = true
        }
        timeDraft = remaining.rounded(.up)
        isEditingTime = true
        return true
    }

    /// Sets the time being picked, clamped to 1 second … 23:59:59.
    func setTimeDraft(_ seconds: TimeInterval) {
        guard isEditingTime else { return }
        timeDraft = min(max(1, seconds.rounded()), Self.maximumTime)
    }

    /// Applies the picked time and ends editing.
    func commitTimeEdit() {
        guard isEditingTime else { return }
        setTimeLeft(timeDraft)
        finishEditingTime()
    }

    /// Ends editing without changing the time.
    func cancelTimeEdit() {
        guard isEditingTime else { return }
        finishEditingTime()
    }

    private func finishEditingTime() {
        isEditingTime = false
        if resumeAfterEditing {
            resumeAfterEditing = false
            start()
        }
    }

    // MARK: Ending sessions

    /// Resets the timer: ends the current session (recording it as unfinished) and puts the
    /// phase back to its full length, dropping any custom time.
    @discardableResult
    func stop() -> Bool {
        guard !isLocked else { return false }
        recordCurrentSession(completed: false)
        resetPhaseClock()
        return true
    }

    /// Moves on to the next phase without completing this one. Skipping a focus session
    /// still counts it toward the cycle.
    @discardableResult
    func skip() -> Bool {
        guard !isLocked else { return false }
        recordCurrentSession(completed: false)
        advance(autoStart: false)
        return true
    }

    /// Restarts the current phase if it has begun; otherwise steps back one phase.
    /// Returns false at the very start of a cycle, where there's nothing to go back to.
    @discardableResult
    func previous() -> Bool {
        guard !isLocked else { return false }
        if hasStarted || fixedLength != nil {
            return stop()
        }
        switch phase {
        case .focus where completedFocus > 0:
            setPhase(.shortBreak)
        case .focus:
            return false
        case .shortBreak, .longBreak:
            completedFocus = max(0, completedFocus - 1)
            setPhase(.focus)
        }
        return true
    }

    /// Starts over at the first focus session of a new cycle.
    @discardableResult
    func resetCycle() -> Bool {
        restartFocus(at: 0)
    }

    /// Goes to focus session `index` of the cycle (0 is the first), from any point in it,
    /// ready to start. Whatever was under way is recorded as unfinished.
    @discardableResult
    func restartFocus(at index: Int) -> Bool {
        guard !isLocked, (0..<cycle).contains(index) else { return false }
        recordCurrentSession(completed: false)
        completedFocus = index
        setPhase(.focus)
        return true
    }

    /// Records an in-progress session as unfinished (on quit; ignores Lock-In).
    func saveIncompleteSession() {
        recordCurrentSession(completed: false)
    }

    // MARK: Ticking

    /// Publishes when the displayed second changes and completes the phase when time runs
    /// out. Called by the run-loop timer, or directly by tests.
    func tick() {
        guard isRunning else { return }
        let whole = Int(remaining.rounded(.up))
        if whole != lastWholeSecond {
            // Redraw once per second, right on the boundary, so digits change on a steady beat.
            lastWholeSecond = whole
            objectWillChange.send()
            if remaining > 0 { onSecond?() }
        }
        if remaining <= 0 { complete() }
    }

    private func startTicker() {
        guard schedulesTicks else { return }
        stopTicker()
        // Checks often (cheap) so second boundaries are caught within ~50 ms; the view only
        // redraws when the second changes. Scheduled on the main run loop, so the callback
        // is already on the main actor.
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.01
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func complete() {
        let autoStart = phase == .focus
            ? activePreset?.startBreakAutomatically ?? settings.startBreakAutomatically
            : activePreset?.startFocusAutomatically ?? settings.startFocusAutomatically
        let finished = recordCurrentSession(completed: true)
        advance(autoStart: autoStart)
        if let finished { onPhaseCompleted?(finished) }
    }

    // MARK: Phase transitions

    /// Saves the current session (unfinished ones only if they ran long enough) and clears it.
    @discardableResult
    private func recordCurrentSession(completed: Bool) -> Session? {
        guard var session = currentSession else { return nil }
        let date = now()
        if let last = session.interruptions.indices.last, session.interruptions[last].finishedAt == nil {
            session.interruptions[last].finishedAt = date
        }
        if completed { session.completedAt = date }
        if completed || date.timeIntervalSince(session.startedAt) >= Self.minimumRecordedDuration {
            store.upsert(session)
        }
        currentSession = nil
        return session
    }

    private func closeOpenInterruption(at date: Date) {
        guard let last = currentSession?.interruptions.indices.last,
              currentSession?.interruptions[last].finishedAt == nil else { return }
        currentSession?.interruptions[last].finishedAt = date
    }

    private func advance(autoStart: Bool) {
        switch phase {
        case .focus:
            completedFocus += 1
            setPhase(completedFocus >= cycle ? .longBreak : .shortBreak)
        case .shortBreak:
            setPhase(.focus)
        case .longBreak:
            completedFocus = 0
            setPhase(.focus)
        }
        if autoStart { start() }
    }

    private func setPhase(_ newPhase: Phase) {
        resetPhaseClock()
        phase = newPhase
        state.set(phase.rawValue, forKey: StateKey.phase)
        state.set(completedFocus, forKey: StateKey.completedFocus)
        onPhaseChanged?(newPhase)
    }

    private func resetPhaseClock() {
        isEditingTime = false
        resumeAfterEditing = false
        stopTicker()
        isRunning = false
        runStartedAt = nil
        bankedTime = 0
        fixedLength = nil
        lastWholeSecond = -1
        objectWillChange.send()
    }
}
