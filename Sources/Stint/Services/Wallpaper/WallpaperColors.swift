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
        settings.didChange
            .sink { [weak self] in self?.refresh() }
            .store(in: &cancellables)
    }

    func refresh() {
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
            let newSample = WallpaperSampler.sample(image, region: region, screenFrame: screenFrame)
            if newSample != sample { sample = newSample }
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
