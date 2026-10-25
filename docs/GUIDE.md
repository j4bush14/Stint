# Stint guide

Everything beyond the [README](../README.md): automating Stint, building and testing it, cutting a release, and how the code is put together.

- [Automation](#automation): shortcuts, AppleScript, `stint://` links
- [Building and testing](#building-and-testing)
- [Releasing](#releasing)
- [How the code is organized](#how-the-code-is-organized)
- [Design notes](#design-notes)

---

## Automation

### Global shortcuts

Turn them on in **Settings › Shortcuts**. They work from any app.

| Shortcut | Does |
|---|---|
| ⌃⌥⌘P | Start or pause the timer |
| ⌃⌥⌘N | Skip to the next session or break |
| ⌃⌥⌘R | Start a new cycle |
| ⌃⌥⌘F | Show or hide the timer window |

### AppleScript

```applescript
tell application "Stint" to begin
tell application "Stint" to name session "Writing"
tell application "Stint" to time left -- seconds
```

| Command | Does |
|---|---|
| `begin` / `halt` | Start or resume / stop and rewind |
| `advance` / `rewind` | Skip to the next phase / restart or step back |
| `new cycle` | Start over at the first focus session |
| `reveal` / `conceal` | Show / hide the timer window |
| `current phase`, `time left`, `session name` | Read the timer's state |
| `name session "…"` | Name the current session |

### Links

Open these from Shortcuts, a launcher, a browser or `open` in Terminal:

| Link | Does |
|---|---|
| `stint://start`, `pause`, `toggle`, `stop`, `skip`, `rewind`, `new-cycle` | Control the timer |
| `stint://show`, `hide`, `history`, `set-time` | Show windows; `set-time` opens the time picker |
| `stint://settings`, `stint://settings/appearance` | Open Settings, optionally at a pane |
| `stint://name?text=Writing` | Name the current session |

---

## Building and testing

You need Xcode 27 (Swift 6.4).

| Command | What it does |
|---|---|
| `make app` | Build `build/Stint.app` |
| `make run` | Build and launch |
| `make install` / `make uninstall` | Copy to / remove from `/Applications` (your data is kept) |
| `make test` | Run every test, unit and UI (about two minutes) |
| `make test-unit` | Run the fast tests only (no windows, about a second) |
| `make test-ui` | Run the UI tests only; they open real windows |
| `make open` | Open the package in Xcode |
| `make logs` | Stream the running app's log messages |
| `make package` | Build `dist/Stint-<version>.dmg` and `.zip` plus checksums |
| `make verify` | Install the packaged `.dmg` as a user would and check it (signature, version, contents, checksums) |
| `make clean` | Remove build products |

**What the tests cover.** The unit tests cover the timer (cycles, pausing, rewind, Lock-In, tag timers, saved state, editing the time), the session store and CSV export, history periods and charts, the menu bar item and its menu, website-blocking rules, commands and `stint://` parsing, wallpaper sampling and colors. They use throwaway preferences and a temporary folder, never your real data.

The UI tests in `Tests/StintTests/UI` host the real views in a real window and click them: transport buttons, the time picker, renaming, every clock style and layout, the panel's menus, every Settings control, tags, History and the session editor. Controls are found by `testTarget` names, which also report what a control shows, so tests check the screen updated, not just the model. `UIHarness` explains how input is delivered.

**The website** lives in [`site/`](../site/README.md): `npm install`, then `npm run dev`. It's published to GitHub Pages by `.github/workflows/pages.yml` whenever `site/` changes on `main`.

**Continuous integration.** Every push and pull request runs, on GitHub's `xcode-27` runner: the full test suite, a package build, and `Scripts/verify-package.sh`, which mounts the `.dmg`, installs the app, checks its signature, version, architecture and bundled files, and launches it. A second job lints, type-checks and builds the website. The packaged build is kept with each run as a downloadable artifact.

---

## Releasing

GitHub Actions builds the app, packages a `.dmg` and a `.zip`, and publishes them as a GitHub Release. Start a release either way:

- **From GitHub:** **Actions › Release › Run workflow**, type the version (e.g. `2.1.0`), and run. The tag is created for you.
- **From Terminal:** `git tag v2.1.0 && git push origin v2.1.0`

The version comes from the tag or what you typed. The package is verified (installed, checked and launched) before anything is published. Releases are ad-hoc signed, and the release notes tell people how to open an un-notarized app. Add these repository secrets to have releases Developer ID signed and notarized instead:

| Secret | Value |
|---|---|
| `MACOS_CERTIFICATE` | Developer ID Application certificate exported as `.p12`, base64-encoded |
| `MACOS_CERTIFICATE_PASSWORD` | Password for that `.p12` |
| `CODESIGN_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `NOTARY_APPLE_ID`, `NOTARY_TEAM_ID`, `NOTARY_PASSWORD` | Apple ID, team ID and app-specific password for `notarytool` |

**Runners.** The workflows use GitHub's `xcode-27` image (macOS 27 with Xcode 27, currently a preview). To use your own Mac, set the `MACOS_RUNNER` repository variable to its label (its runner must be version 2.327.1 or newer); pull requests from forks still run on GitHub's runners, so outside code never runs on your machine.

**Security.** Secrets reach only the steps that sign and notarize, after the tests, and the temporary keychain holding them is deleted when the job ends. Actions are pinned to commits; to update one, replace the hash with the new release's commit. To sign a local build, set `CODESIGN_IDENTITY` (and `NOTARY_PROFILE` to notarize) before `make package`.

---

## How the code is organized

```
Sources/Stint/
  App/                    builds the app and wires it together
    AppDelegate.swift       entry point; creates services and connects timer events
    AppEnvironment.swift    the composition root every view and service gets its objects from
    AppActions.swift        app-level requests views can make (show Settings, resize the panel…)
    Commands/               AppCommand (links, shortcuts, notifications, AppleScript)
    MenuBar/                the menu bar item: what it shows, how it's drawn and animated, its menu
    Windows/                the floating panel, Settings/History/break windows, the main menu
  Domain/                 plain logic, Foundation only
    Timer/                  FocusTimer (the state machine) and Phase
    Sessions/               Session, Tag, SessionStore (JSON on disk), HistoryQuery
    Settings/               AppSettings, the @Pref wrapper, the choices behind each option
    TimeFormat.swift        how times are written everywhere
  Services/               talks to the system
    Blocking/  Coach/  Hotkeys/  Notifications/  System/  Wallpaper/
  UI/                     SwiftUI views
    DesignSystem/           colors, ThemeModel, button styles, scroll wheel, test targets
    TimerPanel/             TimerPanelView and its layouts, plus Faces/, Controls/ and Chrome/
    Settings/               SettingsView, shared rows and switches; Panes/ has one file per pane
    History/                charts, summary, session list and editor
    BreakTakeover/          the full-screen break
Resources/     Info.plist, entitlements, Stint.sdef (AppleScript terminology), blocked-page HTML
Scripts/       build-app.sh, package.sh, app icon generator
Tests/         Swift Testing suites; UI/ drives real views in a real window
site/          the website (Next.js, exported as static files)
docs/          this guide
.github/       CI and release workflows
```

Dependencies point one way: `UI` and `Services` use `Domain`; `App` builds everything and wires it together. Nothing reaches back up.

### Common changes

- **A new command** (something a link, shortcut or script can do): add a case to `AppCommand`, carry it out in `perform(in:)`, and map it from whichever source should trigger it (`init(url:)`, a hotkey, an AppleScript class plus an entry in `Stint.sdef`). `RulesAndParsingTests` shows the pattern.
- **A new setting:** add an `@Pref("area.name")` property to `AppSettings` (multiple-choice options go in `SettingOptions.swift`), then a `SettingToggle`, `StepperRow` or `Picker` in its pane. Services that react to it subscribe to `settings.didChange`.
- **A new clock face:** add a `ClockStyle` case, draw it in `ClockFace`, and give it a menu bar shape in `MenuBarContent`.

---

## Design notes

- **Composition root.** `AppEnvironment` owns the app's objects (settings, store, timer, theme, wallpaper colors, calendar) and its replaceable services. `AppDelegate` builds the live one; tests build one from throwaway preferences and a temporary folder. There are no singletons: views read dependencies from the SwiftUI environment, and services get theirs through their initializers. The one static, `AppEnvironment.scripting`, exists because Cocoa Scripting creates AppleScript command objects itself.
- **Commands.** Links, global shortcuts, notification buttons and AppleScript all turn their input into an `AppCommand`, and `AppCommand.perform(in:)` is the one place commands are carried out.
- **App actions.** Views ask for app-level things (show Settings at a pane, resize the panel, open History) through `AppActions`, a struct of closures in the environment, so the UI never knows about windows or the delegate. Tests record them.
- **Seams.** The on-device model (`FocusCoach`) and open/save panels (`FileDialogs`) are protocols, so tests use fakes.
- **Logic out of views.** `FocusTimer` holds the timer state machine, `HistoryQuery` the History window's periods, filters and chart buckets, and `MenuBarContent` what the menu bar item shows. All are plain Swift, tested directly.
- **Settings.** `AppSettings` persists through a small `@Pref` property wrapper that publishes changes, which `@AppStorage` doesn't do outside views.
- **Panel glass.** The panel is an `NSGlassEffectView`. Its color is a wash inside the content rather than the view's `tintColor`, because `tintColor` disappears whenever the window isn't key. Panel buttons use `PanelGlassButtonStyle` for the same reason: a floating panel shouldn't restyle itself when focus moves.
- **Layouts.** `TimerPanelView.layout(for:)` picks a layout from the window size, and each layout budgets its space so controls can't overlap. Hide and ⋯ sit in the same corners in every layout, and right-click opens the same menu anywhere.
- **Concurrency.** The package builds in Swift 6 language mode with complete checking. The few boundaries (Cocoa Scripting, Carbon hotkeys, notification callbacks, Apple Events to browsers) are handled explicitly.
- **Data.** Sessions and tags are JSON files in `~/Library/Application Support/Stint/`.
