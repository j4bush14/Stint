import AppKit
import Combine

/// Polls the frontmost browser's active tab URL over Apple Events during focus sessions and
/// redirects blocked URLs to a local "Blocked" page.
@MainActor
final class WebBlocker {
    enum Browser: String, CaseIterable {
        case safari = "com.apple.Safari"
        case chrome = "com.google.Chrome"
        case brave = "com.brave.Browser"
        case edge = "com.microsoft.edgemac"
        case arc = "company.thebrowser.Browser"
        case vivaldi = "com.vivaldi.Vivaldi"

        var tabReference: String {
            self == .safari ? "current tab of front window" : "active tab of front window"
        }
    }

    private let settings: AppSettings
    private let timer: FocusTimer
    private let blockedPageURL: URL
    private var pollTimer: Timer?
    private var inFlight = false
    private var cancellables = Set<AnyCancellable>()

    /// - Parameter dataDirectory: where the blocked page is copied so browsers can open it.
    init(settings: AppSettings, timer: FocusTimer, dataDirectory: URL) {
        self.settings = settings
        self.timer = timer
        blockedPageURL = dataDirectory.appendingPathComponent("Blocked.html")
        if let bundled = Bundle.main.url(forResource: "Blocked", withExtension: "html") {
            try? FileManager.default.removeItem(at: blockedPageURL)
            try? FileManager.default.copyItem(at: bundled, to: blockedPageURL)
        }
    }

    func start() {
        Publishers.Merge(timer.objectWillChange.receive(on: RunLoop.main), settings.didChange)
            .sink { [weak self] in self?.updatePolling() }
            .store(in: &cancellables)
    }

    private func updatePolling() {
        let shouldPoll = settings.webBlocking && timer.isFocusing
        if shouldPoll, pollTimer == nil {
            let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.poll() }
            }
            RunLoop.main.add(timer, forMode: .common)
            pollTimer = timer
            poll()
        } else if !shouldPoll, let timer = pollTimer {
            timer.invalidate()
            pollTimer = nil
        }
    }

    private func poll() {
        guard !inFlight,
              let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              let browser = Browser(rawValue: id) else { return }
        let rules = settings.blockedSites
        let mode = settings.webListMode
        let blockedPage = blockedPageURL.absoluteString
        inFlight = true
        Task {
            await Self.redirectIfBlocked(browser, rules: rules, mode: mode, blockedPage: blockedPage)
            inFlight = false
        }
    }

    /// Asks the browser for its current URL and swaps in the blocked page if it matches.
    /// Apple Events block until the browser replies, so this runs off the main actor.
    @concurrent
    nonisolated private static func redirectIfBlocked(_ browser: Browser, rules: [String],
                                                      mode: BlockListMode, blockedPage: String) async {
        let tab = browser.tabReference
        guard let url = run("tell application id \"\(browser.rawValue)\" to get URL of \(tab)"),
              isBlocked(url, rules: rules, mode: mode, blockedPage: blockedPage) else { return }
        let link = blockedPageLink(base: blockedPage, for: url)
        _ = run("tell application id \"\(browser.rawValue)\" to set URL of \(tab) to \"\(link)\"")
    }

    /// The blocked page, told which site was blocked (e.g. `…/Blocked.html?site=reddit.com`).
    nonisolated static func blockedPageLink(base: String, for url: String) -> String {
        guard var host = URL(string: url)?.host() else { return base }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        let encoded = host.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(.init(charactersIn: ".-"))) ?? ""
        return encoded.isEmpty ? base : "\(base)?site=\(encoded)"
    }

    /// Whether a URL is blocked. A rule matches any address containing it; a rule starting
    /// with "=" matches one exact address prefix. Only web pages are ever blocked.
    nonisolated static func isBlocked(_ url: String, rules: [String], mode: BlockListMode, blockedPage: String) -> Bool {
        let lower = url.lowercased()
        guard lower.hasPrefix("http://") || lower.hasPrefix("https://") else { return false }
        if url.hasPrefix(blockedPage) { return false }
        let matches = rules.contains { rule in
            let r = rule.lowercased()
            if r.hasPrefix("=") {
                return lower.hasPrefix(String(r.dropFirst()))
            }
            return lower.contains(r)
        }
        return mode == .block ? matches : !matches
    }

    nonisolated private static func run(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { NSLog("Stint web blocker: \(error)") }
        return result?.stringValue
    }
}
