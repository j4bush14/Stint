import AppKit
import UniformTypeIdentifiers

/// File choosers the app shows. The app uses `SystemFileDialogs`; tests substitute answers.
@MainActor
protocol FileDialogs {
    /// Asks for one or more applications; empty if cancelled.
    func chooseApplications() -> [URL]
    /// Asks where to save a CSV file; nil if cancelled.
    func chooseCSVDestination(suggestedName: String) -> URL?
}

struct SystemFileDialogs: FileDialogs {
    func chooseApplications() -> [URL] {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        return panel.runModal() == .OK ? panel.urls : []
    }

    func chooseCSVDestination(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = suggestedName
        return panel.runModal() == .OK ? panel.url : nil
    }
}
