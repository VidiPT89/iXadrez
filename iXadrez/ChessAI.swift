import Foundation

enum BotDifficulty: String, CaseIterable {
    case beginner, easy, medium, hard
}

private struct LevelConfig {
    var depth: Int
    var margin: Int
    var blunderChance: Double
    var quiescence: Bool
    var timeBudget: TimeInterval
}

private let levels: [BotDifficulty: LevelConfig] = [
    .beginner: LevelConfig(depth: 1, margin: 150, blunderChance: 0.35, quiescence: false, timeBudget: 0.4),
    .easy: LevelConfig(depth: 2, margin: 60, blunderChance: 0.12, quiescence: false, timeBudget: 0.7),
    .medium: LevelConfig(depth: 3, margin: 20, blunderChance: 0, quiescence: true, timeBudget: 1.5),
    .hard: LevelConfig(depth: 4, margin: 0, blunderChance: 0, quiescence: true, timeBudget: 3.0),
]

private let mateScore = 1_000_000

private let pst: [PieceType: [[Int]]] = [
    .pawn: [
        [0, 0, 0, 0, 0, 0, 0, 0],
        [50, 50, 50, 50, 50, 50, 50, 50],
        [10, 10, 20, 30, 30, 20, 10, 10],
        [5, 5, 10, 25, 25, 10, 5, 5],
        [0, 0, 0, 20, 20, 0, 0, 0],
        [5, -5, -10, 0, 0, -10, -5, 5],
        [5, 10, 10, -20, -20, 10, 10, 5],
        [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    .knight: [
        [-50, -40, -30, -30, -30, -30, -40, -50],
        [-40, -20, 0, 0, 0, 0, -20, -40],
        [-30, 0, 10, 15, 15, 10, 0, -30],
        [-30, 5, 15, 20, 20, 15, 5, -30],
        [-30, 0, 15, 20, 20, 15, 0, -30],
        [-30, 5, 10, 15, 15, 10, 5, -30],
        [-40, -20, 0, 5, 5, 0, -20, -40],
        [-50, -40, -30, -30, -30, -30, -40, -50],
    ],
    .bishop: [
        [-20, -10, -10, -10, -10, -10, -10, -20],
        [-10, 0, 0, 0, 0, 0, 0, -10],
        [-10, 0, 5, 10, 10, 5, 0, -10],
        [-10, 5, 5, 10, 10, 5, 5, -10],
        [-10, 0, 10, 10, 10, 10, 0, -10],
        [-10, 10, 10, 10, 10, 10, 10, -10],
        [-10, 5, 0, 0, 0, 0, 5, -10],
        [-20, -10, -10, -10, -10, -10, -10, -20],
    ],
    .rook: [
        [0, 0, 0, 0, 0, 0, 0, 0],
        [5, 10, 10, 10, 10, 10, 10, 5],
        [-5, 0, 0, 0, 0, 0, 0, -5],
        [-5, 0, 0, 0, 0, 0, 0, -5],
        [-5, 0, 0, 0, 0, 0, 0, -5],
        [-5, 0, 0, 0, 0, 0, 0, -5],
        [-5, 0, 0, 0, 0, 0, 0, -5],
        [0, 0, 0, 5, 5, 0, 0, 0],
    ],
    .queen: [
        [-20, -10, -10, -5, -5, -10, -10, -20],
        [-10, 0, 0, 0, 0, 0, 0, -10],
        [-10, 0, 5, 5, 5, 5, 0, -10],
        [-5, 0, 5, 5, 5, 5, 0, -5],
        [0, 0, 5, 5, 5, 5, 0, -5],
        [-10, 5, 5, 5, 5, 5, 0, -10],
        [-10, 0, 5, 0, 0, 0, 0, -10],
        [-20, -10, -10, -5, -5, -10, -10, -20],
    ],
    .king: [
        [-30, -40, -40, -50, -50, -40, -40, -30],
        [-30, -40, -40, -50, -50, -40, -40, -30],
        [-30, -40, -40, -50, -50, -40, -40, -30],
        [-30, -40, -40, -50, -50, -40, -40, -30],
        [-20, -30, -30, -40, -40, -30, -30, -20],
        [-10, -20, -20, -20, -20, -20, -20, -10],
        [20, 20, 0, 0, 0, 0, 20, 20],
        [20, 30, 10, 0, 0, 10, 30, 20],
    ],
]

enum ChessAI {
    private static func evaluate(_ game: ChessGame) -> Int {
        var score = 0
        for r in 0..<8 {
            for c in 0..<8 {
                guard let p = game.board[r][c] else { continue }
                let pstRow = p.color == .white ? r : 7 - r
                let pstVal = pst[p.type]![pstRow][c]
                let sign = p.color == .white ? 1 : -1
                score += sign * (p.type.value + pstVal)
            }
        }
        return score
    }

    private static func orderMoves(_ moves: [Move]) -> [Move] {
        moves.sorted { a, b in
            func score(_ m: Move) -> Int {
                var s = 0
                if m.capture { s += 1000 }
                if m.promotion != nil { s += 900 }
                return s
            }
            return score(a) > score(b)
        }
    }

    private static func quiescence(_ game: ChessGame, alpha: Int, beta: Int, colorSign: Int, qdepth: Int) -> Int {
        var alpha = alpha
        let standPat = colorSign * evaluate(game)
        if qdepth <= 0 { return standPat }
        if standPat >= beta { return beta }
        if standPat > alpha { alpha = standPat }

        let moves = orderMoves(game.allLegalMoves(for: game.turn).filter { $0.capture || $0.promotion != nil })
        for move in moves {
            let child = game.clone()
            child.makeMove(from: move.from, to: move.to, promotion: move.promotion)
            let score = -quiescence(child, alpha: -beta, beta: -alpha, colorSign: -colorSign, qdepth: qdepth - 1)
            if score >= beta { return beta }
            if score > alpha { alpha = score }
        }
        return alpha
    }

    private static func negamax(_ game: ChessGame, depth: Int, alpha: Int, beta: Int, colorSign: Int, useQuiescence: Bool, deadline: Date) -> Int {
        var alpha = alpha
        if game.isGameOver {
            let status = game.gameStatusText()
            return status.key == "checkmate" ? -mateScore - depth : 0
        }
        if depth == 0 {
            return useQuiescence ? quiescence(game, alpha: alpha, beta: beta, colorSign: colorSign, qdepth: 4) : colorSign * evaluate(game)
        }
        if Date() > deadline { return colorSign * evaluate(game) }

        let moves = orderMoves(game.allLegalMoves(for: game.turn))
        if moves.isEmpty {
            return game.isInCheck(game.turn) ? -mateScore - depth : 0
        }

        var best = Int.min / 2
        for move in moves {
            let child = game.clone()
            child.makeMove(from: move.from, to: move.to, promotion: move.promotion)
            let score = -negamax(child, depth: depth - 1, alpha: -beta, beta: -alpha, colorSign: -colorSign, useQuiescence: useQuiescence, deadline: deadline)
            if score > best { best = score }
            if best > alpha { alpha = best }
            if alpha >= beta { break }
        }
        return best
    }

    /// Picks a move for the side to move. Safe to call from a background thread.
    static func pickMove(game: ChessGame, difficulty: BotDifficulty) -> Move? {
        let cfg = levels[difficulty]!
        let rootMoves = game.allLegalMoves(for: game.turn)
        guard !rootMoves.isEmpty else { return nil }

        if Double.random(in: 0..<1) < cfg.blunderChance {
            return rootMoves.randomElement()
        }

        let colorSign = game.turn == .white ? 1 : -1
        let deadline = Date().addingTimeInterval(cfg.timeBudget)
        var scored: [(move: Move, score: Int)] = []

        if cfg.timeBudget >= 1.5 {
            var currentOrder = orderMoves(rootMoves)
            for d in 1...cfg.depth {
                var results: [(move: Move, score: Int)] = []
                for move in currentOrder {
                    let child = game.clone()
                    child.makeMove(from: move.from, to: move.to, promotion: move.promotion)
                    let score = -negamax(child, depth: d - 1, alpha: Int.min / 2, beta: Int.max / 2, colorSign: -colorSign, useQuiescence: cfg.quiescence, deadline: deadline)
                    results.append((move, score))
                    if Date() > deadline { break }
                }
                results.sort { $0.score > $1.score }
                currentOrder = results.map { $0.move }
                scored = results
                if Date() > deadline { break }
            }
        } else {
            for move in orderMoves(rootMoves) {
                let child = game.clone()
                child.makeMove(from: move.from, to: move.to, promotion: move.promotion)
                let score = -negamax(child, depth: cfg.depth - 1, alpha: Int.min / 2, beta: Int.max / 2, colorSign: -colorSign, useQuiescence: cfg.quiescence, deadline: deadline)
                scored.append((move, score))
            }
            scored.sort { $0.score > $1.score }
        }

        guard let best = scored.first?.score else { return rootMoves.randomElement() }
        let within = scored.filter { best - $0.score <= cfg.margin }
        return within.randomElement()?.move
    }
}
