import AppKit

// AppleScript support. Terminology lives in Resources/Stint.sdef, e.g.
//   tell application "Stint" to begin
//   tell application "Stint" to name session "Writing"
//   tell application "Stint" to time left   -- seconds

/// Base for Stint's scripting commands. Cocoa Scripting delivers commands on the main
/// thread, which `assumeIsolated` asserts so subclasses can use main-actor state directly.
class StintScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        // The command object never leaves the main thread; `assumeIsolated` traps if it does.
        nonisolated(unsafe) let command = self
        return MainActor.assumeIsolated { command.run() }
    }

    @MainActor func run() -> (any Sendable)? { nil }

    /// AppKit creates script commands itself, so they read the environment set at launch.
    @MainActor var app: AppEnvironment {
        guard let app = AppEnvironment.scripting else { preconditionFailure("AppleScript before launch finished") }
        return app
    }
    @MainActor var timer: FocusTimer { app.timer }
    @MainActor var phaseName: String { timer.phase.title }
}

@objc(BeginCommand) final class BeginCommand: StintScriptCommand {
    override func run() -> (any Sendable)? { timer.start(); return phaseName }
}

@objc(HaltCommand) final class HaltCommand: StintScriptCommand {
    override func run() -> (any Sendable)? { timer.stop(); return phaseName }
}

@objc(AdvanceCommand) final class AdvanceCommand: StintScriptCommand {
    override func run() -> (any Sendable)? { timer.skip(); return phaseName }
}

@objc(RewindCommand) final class RewindCommand: StintScriptCommand {
    override func run() -> (any Sendable)? { timer.previous(); return phaseName }
}

@objc(NewCycleCommand) final class NewCycleCommand: StintScriptCommand {
    override func run() -> (any Sendable)? { timer.resetCycle(); return phaseName }
}

@objc(RevealCommand) final class RevealCommand: StintScriptCommand {
    override func run() -> (any Sendable)? { app.actions.showPanel(); return nil }
}

@objc(ConcealCommand) final class ConcealCommand: StintScriptCommand {
    override func run() -> (any Sendable)? { app.actions.hidePanel(); return nil }
}

@objc(CurrentPhaseCommand) final class CurrentPhaseCommand: StintScriptCommand {
    override func run() -> (any Sendable)? { phaseName }
}

@objc(TimeLeftCommand) final class TimeLeftCommand: StintScriptCommand {
    override func run() -> (any Sendable)? { Int(timer.remaining.rounded(.up)) }
}

@objc(SessionNameCommand) final class SessionNameCommand: StintScriptCommand {
    override func run() -> (any Sendable)? { timer.title }
}

@objc(NameSessionCommand) final class NameSessionCommand: StintScriptCommand {
    override func run() -> (any Sendable)? {
        let name = (directParameter as? String) ?? ""
        timer.title = name
        return name
    }
}
