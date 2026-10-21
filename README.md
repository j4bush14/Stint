# Stint

A focus timer for the Mac menu bar, built for macOS 27 with Liquid Glass.

Work in short, named stints, take real breaks, and see where your time went. Everything stays on your Mac.

## Features

- **A floating glass timer.** A Liquid Glass panel with a progress ring and three buttons. Hide and ⋯ appear when you point at it. Drag it from anywhere and resize it to any shape; it switches between mini bar, compact, wide and tall layouts.
- **Set any time.** Click the countdown to open a picker: adjust minutes and seconds with the arrows, scroll wheel, drag or arrow keys, or pick a preset. The timer won't start until you click out.
- **Clock styles.** Ring, Digital, Dial (a kitchen-timer wedge) or Flip (a mechanical split-flap display).
- **Cycles.** Focus sessions, short breaks and a long break at the end of each cycle, with optional auto-advance.
- **Color themes.** Lagoon, Ember, Iris, Moss, Rose, Graphite or any custom color. **Wallpaper** uses clear glass and picks up colors from the wallpaper behind the timer. A tint slider sets how much color sits on the glass.
- **Tags.** Drag to reorder. A tag can carry its own timer lengths.
- **History.** Day / week / month / year charts, totals, per-session details and CSV export.
- **Summaries.** A short on-device summary of any period in History, written by Apple Intelligence through the Foundation Models framework. Notifications can use the same model for a line of encouragement.
- **Lock-In.** Disables pause, skip and restart while a focus session runs.
- **Distraction blocking.** Hides listed apps and redirects listed websites in Safari, Chrome, Arc, Brave, Edge and Vivaldi during focus sessions.
- **Break takeover.** An optional full-screen break screen.
- **Calendar logging.** Each finished focus session becomes a calendar event.
- **Automation.** Global hotkeys, AppleScript (`tell application "Stint" to begin`) and `stint://` URLs.

## Install

1. Download the latest **Stint-x.y.dmg** from the [Releases](../../releases) page.
2. Open it and drag **Stint** into **Applications**.
3. Launch Stint. It appears in the menu bar, not the Dock.

If a release isn't notarized, macOS asks before opening it the first time. Choose **Done**, then open **System Settings › Privacy & Security** and click **Open Anyway** next to Stint. Or run:

```bash
xattr -dr com.apple.quarantine /Applications/Stint.app
```

**Requirements:** macOS 27 on Apple silicon. Summaries and encouragement also need Apple Intelligence turned on (optional).

## Build from source

You need Xcode 27 (Swift 6.4).

```bash
git clone <this repository> && cd stint
make install   # build and copy Stint.app to /Applications
```

| Command | What it does |
|---|---|
| `make app` | Build `build/Stint.app` |
| `make run` | Build and launch |
| `make install` / `make uninstall` | Copy to / remove from `/Applications` (your data is kept) |
| `make test` | Run the unit tests |
| `make package` | Build `dist/Stint-<version>.zip` and `.dmg` plus checksums |
| `make clean` | Remove build products |

## Releasing

Push a version tag and GitHub Actions builds, tests, packages and publishes a release with the `.dmg` and `.zip` attached:

```bash
git tag v2.1.0 && git push origin v2.1.0
```

The version comes from the tag. Releases are ad-hoc signed unless these repository secrets are set, in which case they're Developer ID signed and notarized:

| Secret | Value |
|---|---|
| `MACOS_CERTIFICATE` | Developer ID Application certificate exported as `.p12`, base64-encoded |
| `MACOS_CERTIFICATE_PASSWORD` | Password for that `.p12` |
| `CODESIGN_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `NOTARY_APPLE_ID`, `NOTARY_TEAM_ID`, `NOTARY_PASSWORD` | Apple ID, team ID and app-specific password for `notarytool` |

The workflows run on `macos-latest` by default. Set the `MACOS_RUNNER` repository variable to use a runner with Xcode 27, for example a self-hosted Mac; pull requests from forks still run on GitHub's runners, so outside code never runs on your machine. Secrets reach only the steps that sign and notarize, after the tests, and the temporary keychain holding them is deleted when the job ends. Actions are pinned to commits; update a pin by replacing the hash with the new release's commit. To sign locally, set `CODESIGN_IDENTITY` (and `NOTARY_PROFILE` for notarization) before `make package`.

## Project layout

```
Sources/Stint/
  App/         composition root (AppEnvironment, AppDelegate), app actions, menu bar item,
               the floating panel's controller, other windows, main menu,
               AppleScript and stint:// commands
  Domain/      FocusTimer, sessions and tags, settings, history queries (Foundation only)
  Services/    notifications, app/website blocking, hotkeys, calendar, wallpaper colors,
               the on-device coach, file dialogs
  UI/
    DesignSystem/  theme, glass button style, hover highlight, scroll wheel, test targets
    TimerPanel/    adaptive layouts, clock faces, split-flap digits, time picker, chrome
    Settings/      the settings window, one file per pane, shared rows and switches
    History/       charts, summary, session list and editor
Resources/     Info.plist, entitlements, Stint.sdef (AppleScript terminology), blocked-page HTML
Scripts/       build-app.sh, package.sh, app icon generator
Tests/         Swift Testing suites; UI/ drives real views in a real window
.github/       CI and release workflows
```

Dependencies point one way: `UI` and `Services` use `Domain`; `App` builds everything and wires it together. Nothing reaches back up.

### Design notes

- **Composition root.** `AppEnvironment` owns the app's objects (settings, store, timer, theme, wallpaper colors, calendar) and its replaceable services. `AppDelegate` builds the live one; tests build one from throwaway preferences and a temporary folder. There are no singletons: views read their dependencies from the SwiftUI environment, and services get theirs through their initializers. The one static, `AppEnvironment.scripting`, exists because Cocoa Scripting creates AppleScript command objects itself.
- **App actions.** Views ask for app-level things (show Settings at a pane, resize the panel, open History) through `AppActions`, a struct of closures in the environment, so the UI never knows about windows or the delegate. Tests record them.
- **Seams.** The on-device model (`FocusCoach`) and open/save panels (`FileDialogs`) are protocols, so tests use fakes and the UI can be exercised without Apple Intelligence or a modal dialog.
- **Logic out of views.** `FocusTimer` holds the timer state machine and `HistoryQuery` the History window's periods, filtering, titles and chart buckets. Both are plain Swift with injected clocks and calendars, tested directly.
- **Settings.** `AppSettings` persists through a small `@Pref` property wrapper that publishes changes, which `@AppStorage` doesn't do outside views.
- **Panel glass.** The panel is an `NSGlassEffectView`. Its color is a wash inside the content rather than the view's `tintColor`, because `tintColor` disappears whenever the window isn't key. Panel buttons use `PanelGlassButtonStyle` rather than the system glass styles for the same reason: a floating panel shouldn't restyle itself when focus moves.
- **Layouts.** `TimerPanelView.layout(for:)` picks a layout from the window size. Each layout budgets its space explicitly so controls can't overlap at any size. Right-click and the ⋯ button share one menu in every layout.
- **Concurrency.** The package builds in Swift 6 language mode with complete checking. The few boundaries (Cocoa Scripting, Carbon hotkeys, notification delegate callbacks, Apple Events to browsers) are handled explicitly.
- **Data.** Sessions and tags are JSON files in `~/Library/Application Support/Stint/`.

### Tests

`make test` runs the Swift Testing suites in `Tests/StintTests`. They cover the timer (cycles, pausing, rewind, Lock-In, tag timers, saved state, editing the time), the session store and CSV export, history periods and charts, website-blocking rules, `stint://` parsing, wallpaper sampling, scroll stepping, panel layout selection, settings persistence and colors. Tests use throwaway preferences and a temporary folder, never your real data.

UI tests in `Tests/StintTests/UI` host the real views in a real window and click them: every transport button, the time picker (arrows, presets, keys, dragging, click-outside), renaming, each clock style and layout, the ⋯, right-click and tag menus, every Settings switch, stepper and pop-up, choosing apps to block, tag deletion and colors, History ranges and summaries, and the session editor. Controls are found by `testTarget` names, which also report what a control displays, so tests check that the screen updated, not just the model. `UIHarness` explains how input is delivered and the few things covered one level down instead.

## AppleScript

| Command | Does |
|---|---|
| `begin` / `halt` | Start or resume / stop and rewind |
| `advance` / `rewind` | Skip to the next phase / restart or step back |
| `new cycle` | Start over at the first focus session |
| `reveal` / `conceal` | Show / hide the panel |
| `current phase`, `time left`, `session name` | Read state (`time left` is in seconds) |
| `name session "Writing"` | Set the session name |

URLs: `stint://start`, `pause`, `toggle`, `stop`, `skip`, `rewind`, `new-cycle`, `show`, `hide`, `history`, `set-time`, `settings` (or `settings/appearance` etc.), `name?text=Writing`.

## Privacy

Stint has no accounts, analytics or network services. Summaries and encouragement use the on-device model. Website blocking asks macOS for permission to control each browser, and calendar logging asks for calendar access.
