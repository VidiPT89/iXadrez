import Foundation
import Combine

/// One reviewed game, kept on the device so the Coach can track progress over time.
struct SavedReview: Codable, Identifiable, Equatable {
    var id: String { moves }
    let date: Date
    /// "e2e4,e7e5,…" with the promotion piece appended ("e7e8q").
    let moves: String
    /// The color the user played; nil when both sides were played on the same device (1 vs 1).
    let playerColor: String?
    let accuracy: Int
    let themes: [CoachTheme]
    let mistakes: Int
}

final class CoachStore: ObservableObject {
    static let shared = CoachStore()
    private static let key = "xadrez-coach-reviews"
    private static let limit = 30

    @Published private(set) var reviews: [SavedReview] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([SavedReview].self, from: data) {
            reviews = saved
        }
    }

    func save(report: CoachReport, records: [MoveRecord], playerColor: PieceColor?) {
        guard !records.isEmpty else { return }
        let encoded = Self.encode(records)
        let accuracy: Int
        switch playerColor {
        case .white: accuracy = report.accuracyWhite
        case .black: accuracy = report.accuracyBlack
        case nil: accuracy = (report.accuracyWhite + report.accuracyBlack) / 2
        }
        let mine = report.moves.filter { playerColor == nil || $0.record.color == playerColor }
        let entry = SavedReview(date: Date(), moves: encoded, playerColor: playerColor?.rawValue, accuracy: accuracy,
                                themes: report.themes(for: playerColor),
                                mistakes: mine.filter { $0.quality >= .mistake }.count)
        reviews.removeAll { $0.moves == encoded }
        reviews.insert(entry, at: 0)
        if reviews.count > Self.limit { reviews.removeLast(reviews.count - Self.limit) }
        if let data = try? JSONEncoder().encode(reviews) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func delete(_ review: SavedReview) {
        reviews.removeAll { $0 == review }
        if let data = try? JSONEncoder().encode(reviews) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    /// Average accuracy over the most recent games, or nil with no history.
    var recentAccuracy: Int? {
        let recent = reviews.prefix(10)
        guard !recent.isEmpty else { return nil }
        return recent.map(\.accuracy).reduce(0, +) / recent.count
    }

    /// Themes ranked by how often they appeared in the most recent games.
    var topThemes: [(theme: CoachTheme, count: Int)] {
        var counts: [CoachTheme: Int] = [:]
        for review in reviews.prefix(10) {
            for theme in review.themes { counts[theme, default: 0] += 1 }
        }
        return counts.sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }

    static func encode(_ records: [MoveRecord]) -> String {
        records.map { $0.from.name + $0.to.name + ($0.promotion?.rawValue ?? "") }.joined(separator: ",")
    }

    /// Replays an encoded move list; stops at the first move that isn't legal.
    static func decode(_ moves: String) -> [MoveRecord] {
        let game = ChessGame()
        for token in moves.split(separator: ",").map(Array.init) where token.count >= 4 {
            guard let from = square(token[0], token[1]), let to = square(token[2], token[3]) else { break }
            let promo = token.count > 4 ? PieceType(rawValue: String(token[4])) : nil
            if game.makeMove(from: from, to: to, promotion: promo) == nil { break }
        }
        return game.history
    }

    private static func square(_ file: Character, _ rank: Character) -> Square? {
        guard let c = Array("abcdefgh").firstIndex(of: file), let n = rank.wholeNumberValue, (1...8).contains(n) else { return nil }
        return Square(r: 8 - n, c: c)
    }
}
