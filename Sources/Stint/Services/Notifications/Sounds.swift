import AppKit

/// Uses the built-in macOS alert sounds.
@MainActor
enum Sounds {
    static let names = ["None", "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
                        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]

    private static var current: NSSound?

    static func play(_ name: String, volume: Double) {
        guard name != "None", let sound = NSSound(named: NSSound.Name(name))?.copy() as? NSSound else { return }
        sound.volume = Float(volume)
        current = sound
        sound.play()
    }

    private static let tickSound: NSSound? = {
        let s = NSSound(named: "Tink")?.copy() as? NSSound
        s?.volume = 0.12
        return s
    }()

    static func tick() {
        tickSound?.stop()
        tickSound?.play()
    }
}
