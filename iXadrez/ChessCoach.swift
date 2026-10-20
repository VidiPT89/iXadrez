import Foundation

enum MoveQuality: String, Codable, CaseIterable {
    case best, good, inaccuracy, mistake, blunder

    var symbol: String {
        switch self {
        case .best: return "★"
        case .good: return "✓"
        case .inaccuracy: return "?!"
        case .mistake: return "?"
        case .blunder: return "??"
        }
    }
}

/// The recurring tactical patterns the Coach can recognise and explain.
enum CoachTheme: String, Codable, CaseIterable {
    case hangingPiece, allowedMate, missedMate, missedFork, missedCapture
}

struct CoachMoveReview: Identifiable {
    let id: Int // ply index into the game
    let record: MoveRecord
    let quality: MoveQuality
    let theme: CoachTheme?
    let bestFrom: Square?
    let bestTo: Square?
    let evalAfter: Int // centipawns from White's point of view, clamped for display
    let textPt: String
    let textEn: String

    func text(_ lang: AppLanguage) -> String { lang == .pt ? textPt : textEn }
}

struct CoachReport {
    let moves: [CoachMoveReview]
    /// Board after each ply; boards[0] is the starting position.
    let boards: [Board]
    let accuracyWhite: Int
    let accuracyBlack: Int

    func count(_ quality: MoveQuality, for color: PieceColor) -> Int {
        moves.filter { $0.record.color == color && $0.quality == quality }.count
    }

    func themes(for color: PieceColor?) -> [CoachTheme] {
        moves.filter { color == nil || $0.record.color == color }.compactMap(\.theme)
    }
}

/// Grades every move of a game against the engine and explains, in plain language, what went
/// wrong (or right) — the pieces left hanging, the forks and mates that were missed.
enum ChessCoach {
    private static let displayClamp = 2000

    static func review(_ records: [MoveRecord], progress: (Double) -> Void = { _ in }) -> CoachReport {
        let game = ChessGame()
        var positions: [ChessGame] = [game.clone()]
        for record in records {
            game.makeMove(from: record.from, to: record.to, promotion: record.promotion)
            positions.append(game.clone())
        }

        // One search per position: the score after a move is the negated score of the next one.
        // Positions are independent, so they're searched in parallel across the device's cores.
        var analyses = [(best: Move?, score: Int, moves: [(move: Move, score: Int)])](repeating: (nil, 0, []), count: positions.count)
        let lock = NSLock()
        var done = 0
        DispatchQueue.concurrentPerform(iterations: positions.count) { i in
            let result = ChessAI.analyse(game: positions[i])
            lock.lock()
            analyses[i] = result
            done += 1
            let fraction = Double(done) / Double(positions.count)
            lock.unlock()
            progress(fraction)
        }

        var reviews: [CoachMoveReview] = []
        var accuracy: [PieceColor: [Double]] = [.white: [], .black: []]
        for (i, record) in records.enumerated() {
            let before = positions[i], after = positions[i + 1]
            let bestScore = clamp(analyses[i].score)
            let played = analyses[i].moves.first { $0.move.from == record.from && $0.move.to == record.to && $0.move.promotion == record.promotion }
            let playedScore = clamp(played?.score ?? -analyses[i + 1].score)
            let best = analyses[i].best
            let playedBest = best.map { $0.from == record.from && $0.to == record.to && $0.promotion == record.promotion } ?? true
            let loss = playedBest ? 0 : max(0, bestScore - playedScore)

            var quality = grade(loss: loss, playedBest: playedBest)
            var theme: CoachTheme? = nil
            var pt = "", en = ""
            let side = sideNames(record.color)
            let bestSan = best.flatMap { san(of: $0, in: before) } ?? ""

            if ChessAI.isMateScore(analyses[i].score), analyses[i].score > 0, !playedBest, !ChessAI.isMateScore(analyses[i + 1].score) {
                theme = .missedMate
                quality = playedScore >= 500 ? max(quality, .mistake) : .blunder
                pt = "Havia mate! \(sanText(bestSan, .pt)) levava a xeque-mate forçado e esta oportunidade escapou."
                en = "There was a mate! \(bestSan) led to a forced checkmate and the chance slipped away."
            } else if ChessAI.isMateScore(analyses[i + 1].score), analyses[i + 1].score > 0, !after.isGameOver, quality >= .mistake {
                theme = .allowedMate
                quality = .blunder
                let reply = analyses[i + 1].best.flatMap { san(of: $0, in: after) } ?? ""
                pt = "Este lance abre caminho ao mate: as \(side.oppPt) começam com \(sanText(reply, .pt)). Era preciso \(sanText(bestSan, .pt)) para defender o rei."
                en = "This move allows a mating attack: \(side.oppEn) start with \(reply). \(bestSan) was needed to defend the king."
            } else if quality >= .mistake, let reply = analyses[i + 1].best, reply.capture,
                      let victim = reply.enPassant ? Piece(type: .pawn, color: record.color) : after.board[reply.to.r][reply.to.c],
                      victim.type != .pawn || loss >= 200 {
                theme = .hangingPiece
                let replySan = san(of: reply, in: after) ?? ""
                pt = "\(capitalized(article(victim.type))) em \(reply.to.name) ficou sem defesa suficiente: as \(side.oppPt) ganham material com \(sanText(replySan, .pt)). Melhor era \(sanText(bestSan, .pt))."
                en = "The \(nameEn(victim.type)) on \(reply.to.name) was left without enough defence: \(side.oppEn) win material with \(replySan). \(bestSan) was better."
            } else if quality >= .inaccuracy, let best, let targets = forkTargets(best, in: before) {
                theme = .missedFork
                pt = "Faltou ver o garfo \(sanText(bestSan, .pt)): atacava \(targets.pt) ao mesmo tempo."
                en = "The fork \(bestSan) was missed: it hit \(targets.en) at once."
            } else if quality >= .inaccuracy, let best, best.capture,
                      let victim = before.board[best.to.r][best.to.c], victim.type != .pawn {
                theme = .missedCapture
                pt = "Podias ter capturado \(article(victim.type)) em \(best.to.name) com \(sanText(bestSan, .pt))."
                en = "You could have captured the \(nameEn(victim.type)) on \(best.to.name) with \(bestSan)."
            } else if quality >= .inaccuracy {
                let from = pawns(bestScore, record.color), to = pawns(playedScore, record.color)
                pt = "Havia melhor: \(sanText(bestSan, .pt)). A avaliação passa de \(from) para \(to)."
                en = "There was better: \(bestSan). The evaluation goes from \(from) to \(to)."
            } else if record.status == "checkmate" {
                pt = "Xeque-mate! Partida fechada com estilo."
                en = "Checkmate! Game finished in style."
            } else if let targets = forkTargets(Move(from: record.from, to: record.to, piece: Piece(type: record.piece, color: record.color), promotion: record.promotion), in: before) {
                pt = "Garfo! Este lance ataca \(targets.pt) ao mesmo tempo."
                en = "Fork! This move hits \(targets.en) at once."
            } else if quality == .best {
                pt = "Melhor lance da posição."
                en = "The best move in the position."
            } else {
                pt = "Bom lance. O motor preferia \(sanText(bestSan, .pt)), mas a diferença é pequena."
                en = "Good move. The engine preferred \(bestSan), but the difference is small."
            }

            accuracy[record.color, default: []].append(moveAccuracy(before: bestScore, after: playedScore))
            reviews.append(CoachMoveReview(
                id: i, record: record, quality: quality, theme: theme,
                bestFrom: playedBest ? nil : best?.from, bestTo: playedBest ? nil : best?.to,
                evalAfter: record.color == .white ? playedScore : -playedScore,
                textPt: pt, textEn: en
            ))
        }

        func average(_ values: [Double]) -> Int {
            values.isEmpty ? 0 : Int((values.reduce(0, +) / Double(values.count)).rounded())
        }
        return CoachReport(moves: reviews, boards: positions.map(\.board),
                           accuracyWhite: average(accuracy[.white] ?? []), accuracyBlack: average(accuracy[.black] ?? []))
    }

    static func grade(loss: Int, playedBest: Bool) -> MoveQuality {
        if playedBest || loss <= 10 { return .best }
        if loss < 50 { return .good }
        if loss < 120 { return .inaccuracy }
        if loss < 300 { return .mistake }
        return .blunder
    }

    /// Win-probability based accuracy: small slips cost little, throwing away a won game costs a lot.
    static func moveAccuracy(before: Int, after: Int) -> Double {
        func win(_ cp: Int) -> Double { 50 + 50 * (2 / (1 + exp(-0.00368208 * Double(cp))) - 1) }
        let drop = max(0, win(before) - win(after))
        return min(100, max(0, 103.1668 * exp(-0.04354 * drop) - 3.1669))
    }

    // MARK: Helpers

    private static func clamp(_ score: Int) -> Int { min(displayClamp, max(-displayClamp, score)) }

    private static func san(of move: Move, in position: ChessGame) -> String? {
        position.clone().makeMove(from: move.from, to: move.to, promotion: move.promotion)?.san
    }

    /// Pieces worth more than the attacker (or the king) that `move` attacks once played — two or more is a fork.
    private static func forkTargets(_ move: Move, in position: ChessGame) -> (pt: String, en: String)? {
        let child = position.clone()
        guard child.makeMove(from: move.from, to: move.to, promotion: move.promotion) != nil,
              let attacker = child.board[move.to.r][move.to.c] else { return nil }
        child.turn = attacker.color
        child.result = nil
        let hits = child.legalMoves(from: move.to)
            .filter(\.capture)
            .compactMap { child.board[$0.to.r][$0.to.c] }
            .filter { $0.type == .king || ($0.type != .pawn && $0.type.value > attacker.type.value) }
        guard hits.count >= 2 else { return nil }
        let sorted = hits.sorted { $0.type.value > $1.type.value }
        return (sorted.map { article($0.type) }.joined(separator: " e "),
                "the " + sorted.map { nameEn($0.type) }.joined(separator: " and the "))
    }

    private static func pawns(_ score: Int, _ mover: PieceColor) -> String {
        let white = mover == .white ? score : -score
        return String(format: "%+.1f", Double(white) / 100)
    }

    private static func sideNames(_ color: PieceColor) -> (oppPt: String, oppEn: String) {
        color == .white ? ("Pretas", "Black") : ("Brancas", "White")
    }

    static func article(_ type: PieceType) -> String {
        switch type {
        case .pawn: return "o peão"
        case .knight: return "o cavalo"
        case .bishop: return "o bispo"
        case .rook: return "a torre"
        case .queen: return "a dama"
        case .king: return "o rei"
        }
    }

    static func nameEn(_ type: PieceType) -> String {
        switch type {
        case .pawn: return "pawn"
        case .knight: return "knight"
        case .bishop: return "bishop"
        case .rook: return "rook"
        case .queen: return "queen"
        case .king: return "king"
        }
    }

    private static func capitalized(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }
}

extension MoveQuality: Comparable {
    static func < (lhs: MoveQuality, rhs: MoveQuality) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}
