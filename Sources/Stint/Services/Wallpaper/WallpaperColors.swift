import AppKit
import Combine

/// Keeps a color sample of the wallpaper behind the timer panel while the Wallpaper
/// theme is selected. Refreshes when the panel moves or resizes, the Space or displays
/// change, and every so often to notice a new wallpaper.
@MainActor
final class WallpaperColors: ObservableObject {
    /// The latest sample, or nil when the wallpaper can't be read (clear glass is used alone).
    @Published private(set) var sample: WallpaperSampler.Sample?

    private weak var window: NSWindow?
    private var thumbnail: (url: URL, modified: Date?, image: CGImage)?
    private var refreshTask: Task<Void, Never>?
    private var periodicRefresh: Timer?
    /// While the panel moves or resizes: when the last sample was taken, and the one
    /// waiting to run once movement pauses.
    private var lastRefresh = Date.distantPast
    private var trailingRefresh: Timer?
    private var lastPalette: Palette?
    private var cancellables = Set<AnyCancellable>()
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// Starts following `window`. Call once; refreshes happen automatically afterwards.
    func track(_ window: NSWindow) {
        self.window = window
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .merge(with: NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification))
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        // Only a change of theme matters here, not every setting.
        settings.didChange
            .sink { [weak self] in
                guard let self, settings.palette != lastPalette else { return }
                refresh()
            }
            .store(in: &cancellables)
    }

    /// Samples again while the panel is being moved or resized: at most every
    /// `minimumInterval`, plus once after it settles, so colors follow smoothly without a
    /// sample for every mouse event.
    func refreshSoon(minimumInterval: TimeInterval = 0.12) {
        guard settings.palette == .wallpaper else { return }
        trailingRefresh?.invalidate()
        let wait = minimumInterval - Date().timeIntervalSince(lastRefresh)
        if wait <= 0 {
            refresh()
        }
        let timer = Timer(timeInterval: max(wait, 0) + minimumInterval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        trailingRefresh = timer
    }

    func refresh() {
        lastPalette = settings.palette
        lastRefresh = Date()
        guard settings.palette == .wallpaper else {
            stopPeriodicRefresh()
            return
        }
        startPeriodicRefresh()
        guard let window, let screen = window.screen ?? NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen),
              WallpaperSampler.canRead(url) else {
            sample = nil
            return
        }
        let region = window.frame
        let screenFrame = screen.frame
        refreshTask?.cancel()
        refreshTask = Task {
            guard let image = await image(at: url), !Task.isCancelled else { return }
            // A region that can't be sampled for a moment (mid-way between displays) keeps the
            // last colors rather than flashing to the plain scrim.
            guard let newSample = WallpaperSampler.sample(image, region: region, screenFrame: screenFrame),
                  newSample != sample else { return }
            sample = newSample
        }
    }

    // MARK: Private

    /// The decoded thumbnail, reused until the file changes.
    private func image(at url: URL) async -> CGImage? {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        if let thumbnail, thumbnail.url == url, thumbnail.modified == modified {
            return thumbnail.image
        }
        guard let image = await Self.decode(url) else { return nil }
        thumbnail = (url, modified, image)
        return image
    }

    @concurrent
    nonisolated private static func decode(_ url: URL) async -> CGImage? {
        WallpaperSampler.loadThumbnail(url)
    }

    private func startPeriodicRefresh() {
        guard periodicRefresh == nil else { return }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        periodicRefresh = timer
    }

    private func stopPeriodicRefresh() {
        periodicRefresh?.invalidate()
        periodicRefresh = nil
        if sample != nil { sample = nil }
    }
}
