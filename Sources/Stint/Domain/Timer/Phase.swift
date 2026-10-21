import Foundation

/// A stretch of the cycle: focusing or one of the two kinds of break.
enum Phase: String, Codable, CaseIterable, Identifiable {
    case focus, shortBreak, longBreak
    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var isBreak: Bool { self != .focus }
}
