import Foundation
import Combine
import SwiftUI

enum GameMode {
    case oneVOne, bot
}

@MainActor
final class GameViewModel: ObservableObject {
    static let botColor: PieceColor = .black

    @Published private(set) var game = ChessGame()
    @Published private(set) var pieces: [PieceInstance] = []
    @Published var selected: Square? = nil
    @Published private(set) var legalTargets: [Move] = []
    @Published var flipped: Bool = false
    @Published private(set) var lastMove: (from: Square, to: Square)? = nil
    @Published var mode: GameMode = .oneVOne
    @Published var botLevel: BotDifficulty = .medium
    @Published private(set) var thinking: Bool = false
    @Published var promotionCandidates: [Move]? = nil
    @Published var showResult: Bool = false
    @Published private(set) var canRedo: Bool = false

    private var requestToken = UUID()
    private var redoStack: [[MoveRecord]] = []

    func newGame(mode: GameMode, level: BotDifficulty = .medium) {
        self.mode = mode
        self.botLevel = level
        requestToken = UUID()
        game = ChessGame()
        pieces = PieceInstance.fresh(from: game.board)
        selected = nil
        legalTargets = []
        lastMove = nil
        thinking = false
        promotionCandidates = nil
        showResult = false
        redoStack = []
        canRedo = false
    }

    var statusText: (over: Bool, key: String, winner: PieceColor?) {
        let s = game.gameStatusText()
        return (s.over, s.key, s.winner)
    }

    func tapSquare(_ square: Square) {
        guard !thinking, !game.isGameOver else { return }
        if let sel = selected {
            let candidates = legalTargets.filter { $0.to == square }
            if !candidates.isEmpty {
                attemptMove(candidates)
                return
            }
        }
        if let piece = game.pieceAt(square.r, square.c), piece.color == game.turn {
            selected = square
            legalTargets = game.legalMoves(from: square)
            SoundEngine.shared.playClick()
        } else {
            selected = nil
            legalTargets = []
        }
    }

    private func attemptMove(_ candidates: [Move]) {
        if candidates.count > 1 {
            promotionCandidates = candidates
            return
        }
        finalize(candidates[0])
    }

    func choosePromotion(_ type: PieceType) {
        guard let candidates = promotionCandidates else { return }
        let chosen = candidates.first { $0.promotion == type } ?? candidates[0]
        promotionCandidates = nil
        finalize(chosen)
    }

    private func finalize(_ move: Move) {
        let wasCapture = move.capture
        guard let record = game.makeMove(from: move.from, to: move.to, promotion: move.promotion) else { return }
        selected = nil
        legalTargets = []
        lastMove = (move.from, move.to)
        redoStack = []
        canRedo = false

        withAnimation(.easeInOut(duration: 0.38)) {
            applyMoveToPieces(move)
        }

        if record.status == "check" { SoundEngine.shared.playCheck() }
        else if game.isGameOver { SoundEngine.shared.playEnd() }
        else if wasCapture { SoundEngine.shared.playCapture() }
        else { SoundEngine.shared.playMove() }

        if game.isGameOver {
            showResult = true
            return
        }
        if mode == .bot, game.turn == Self.botColor {
            requestBotMove()
        }
    }

    /// Updates the piece-instance list in place, preserving identity so SwiftUI slides the
    /// moved piece(s) from their old square to the new one instead of popping in/out.
    private func applyMoveToPieces(_ move: Move) {
        var updated = pieces

        if move.enPassant {
            let capR = move.piece.color == .white ? move.to.r + 1 : move.to.r - 1
            updated.removeAll { $0.square == Square(r: capR, c: move.to.c) }
        } else if move.capture {
            updated.removeAll { $0.square == move.to }
        }

        if let idx = updated.firstIndex(where: { $0.square == move.from }) {
            updated[idx].square = move.to
            if let promo = move.promotion { updated[idx].type = promo }
        }

        if let castle = move.castle {
            let rank = move.from.r
            let rookFromC = castle == "K" ? 7 : 0
            let rookToC = castle == "K" ? 5 : 3
            if let rIdx = updated.firstIndex(where: { $0.square == Square(r: rank, c: rookFromC) }) {
                updated[rIdx].square = Square(r: rank, c: rookToC)
            }
        }

        pieces = updated
    }

    /// So the bot always feels like it "thought" for a moment, even at Beginner/Easy where
    /// the search itself finishes almost instantly.
    private static let botMinDelay: TimeInterval = 0.55

    private func requestBotMove() {
        thinking = true
        let token = requestToken
        let snapshot = game.clone()
        let level = botLevel
        let startedAt = Date()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let move = ChessAI.pickMove(game: snapshot, difficulty: level)
            let elapsed = Date().timeIntervalSince(startedAt)
            let wait = max(0, Self.botMinDelay - elapsed)
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
                guard let self, self.requestToken == token else { return }
                self.thinking = false
                if let move {
                    self.finalize(Move(from: move.from, to: move.to, piece: move.piece, capture: self.game.pieceAt(move.to.r, move.to.c) != nil, promotion: move.promotion))
                }
            }
        }
    }

    func undoLastTurn() {
        guard mode == .bot, !thinking, !game.history.isEmpty else { return }
        let removeCount = game.history.count % 2 == 0 ? 2 : 1
        let removed = Array(game.history.suffix(removeCount))
        redoStack.append(removed)
        canRedo = true
        requestToken = UUID()
        game.undoPlies(removeCount)
        pieces = PieceInstance.fresh(from: game.board)
        selected = nil
        legalTargets = []
        lastMove = nil
        showResult = false
        SoundEngine.shared.playClick()
    }

    func redoLastTurn() {
        guard mode == .bot, !thinking, let batch = redoStack.popLast() else { return }
        for record in batch {
            game.makeMove(from: record.from, to: record.to, promotion: record.promotion)
        }
        canRedo = !redoStack.isEmpty
        pieces = PieceInstance.fresh(from: game.board)
        if let last = batch.last { lastMove = (last.from, last.to) }
        SoundEngine.shared.playClick()
    }

    func flipBoard() { flipped.toggle() }

    func isKingInCheckSquare() -> Square? {
        game.isInCheck(game.turn) ? game.findKing(game.turn) : nil
    }
}
