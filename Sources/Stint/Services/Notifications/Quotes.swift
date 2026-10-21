import Foundation

/// A small set of public-domain-style quotes shown after a finished focus session.
enum Quotes {
    static let all: [(String, String)] = [
        ("The secret of getting ahead is getting started.", "Mark Twain"),
        ("It always seems impossible until it's done.", "Nelson Mandela"),
        ("Well done is better than well said.", "Benjamin Franklin"),
        ("Simplicity is the ultimate sophistication.", "Leonardo da Vinci"),
        ("Quality is not an act, it is a habit.", "Aristotle"),
        ("What we think, we become.", "Buddha"),
        ("Action is the foundational key to all success.", "Pablo Picasso"),
        ("Energy and persistence conquer all things.", "Benjamin Franklin"),
        ("Do the best you can until you know better.", "Maya Angelou"),
        ("Little by little, one travels far.", "J. R. R. Tolkien"),
        ("Nothing will work unless you do.", "Maya Angelou"),
        ("Rest is not idleness.", "John Lubbock"),
        ("He who has a why can bear almost any how.", "Friedrich Nietzsche"),
        ("You miss 100% of the shots you don't take.", "Wayne Gretzky"),
        ("The journey of a thousand miles begins with one step.", "Lao Tzu"),
        ("Focus is a matter of deciding what things you're not going to do.", "John Carmack"),
    ]

    static func random() -> String {
        let q = all.randomElement()!
        return "“\(q.0)” — \(q.1)"
    }
}
