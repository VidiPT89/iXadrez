import Foundation

enum PieceColor: String, Equatable {
    case white = "w"
    case black = "b"

    var opponent: PieceColor { self == .white ? .black : .white }
}

enum PieceType: String, Equatable {
    case pawn = "p", knight = "n", bishop = "b", rook = "r", queen = "q", king = "k"

    var value: Int {
        switch self {
        case .pawn: return 100
        case .knight: return 320
        case .bishop: return 330
        case .rook: return 500
        case .queen: return 900
        case .king: return 20000
        }
    }
}

struct Piece: Equatable {
    var type: PieceType
    var color: PieceColor
}

struct Square: Equatable, Hashable {
    var r: Int
    var c: Int

    var name: String {
        let files = Array("abcdefgh")
        return "\(files[c])\(8 - r)"
    }

    func inBounds() -> Bool { r >= 0 && r < 8 && c >= 0 && c < 8 }
}

struct Move: Equatable {
    var from: Square
    var to: Square
    var piece: Piece
    var capture: Bool = false
    var promotion: PieceType? = nil
    var enPassant: Bool = false
    var doubleStep: Bool = false
    var castle: String? = nil // "K" or "Q"
}

struct CastlingRights: Equatable {
    var wK = true, wQ = true, bK = true, bQ = true
}

struct MoveRecord {
    var san: String
    var from: Square
    var to: Square
    var piece: PieceType
    var color: PieceColor
    var capture: Bool
    var promotion: PieceType?
    var castle: String?
    var status: String // "ok" | "check" | "checkmate" | "stalemate" | "draw"
}

enum GameResult: Equatable {
    case checkmate, stalemate, draw50, drawRepetition, drawMaterial
}

struct GameStatus {
    var over: Bool
    var key: String
    var winner: PieceColor?
}

typealias Board = [[Piece?]]

private let knightOffsets = [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)]
private let kingOffsets = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
private let bishopDirs = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
private let rookDirs = [(-1, 0), (1, 0), (0, -1), (0, 1)]

func initialBoard() -> Board {
    let back: [PieceType] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
    var board: Board = []
    board.append(back.map { Piece(type: $0, color: .black) })
    board.append(Array(repeating: Piece(type: .pawn, color: .black), count: 8))
    for _ in 0..<4 { board.append(Array(repeating: nil, count: 8)) }
    board.append(Array(repeating: Piece(type: .pawn, color: .white), count: 8))
    board.append(back.map { Piece(type: $0, color: .white) })
    return board
}

final class ChessGame {
    var board: Board = initialBoard()
    var turn: PieceColor = .white
    var castling = CastlingRights()
    var enPassant: Square? = nil
    var halfmoveClock = 0
    var fullmoveNumber = 1
    var history: [MoveRecord] = []
    var positionCounts: [String: Int] = [:]
    var result: GameResult? = nil
    var winner: PieceColor? = nil

    init() {
        recordPosition()
    }

    func clone() -> ChessGame {
        let g = ChessGame()
        g.board = board
        g.turn = turn
        g.castling = castling
        g.enPassant = enPassant
        g.halfmoveClock = halfmoveClock
        g.fullmoveNumber = fullmoveNumber
        g.history = history
        g.positionCounts = positionCounts
        g.result = result
        g.winner = winner
        return g
    }

    func pieceAt(_ r: Int, _ c: Int) -> Piece? { board[r][c] }

    var isGameOver: Bool { result != nil }

    private func positionKey() -> String {
        var key = turn.rawValue
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c] { key += p.color.rawValue + p.type.rawValue } else { key += "." }
            }
        }
        key += "|\(castling.wK ? 1 : 0)\(castling.wQ ? 1 : 0)\(castling.bK ? 1 : 0)\(castling.bQ ? 1 : 0)"
        key += "|\(enPassant?.name ?? "-")"
        return key
    }

    private func recordPosition() {
        let key = positionKey()
        positionCounts[key, default: 0] += 1
    }

    func findKing(_ color: PieceColor) -> Square? {
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.type == .king, p.color == color { return Square(r: r, c: c) }
            }
        }
        return nil
    }

    func isSquareAttacked(_ r: Int, _ c: Int, by byColor: PieceColor) -> Bool {
        for (dr, dc) in knightOffsets {
            let rr = r + dr, cc = c + dc
            if Square(r: rr, c: cc).inBounds(), let p = board[rr][cc], p.color == byColor, p.type == .knight { return true }
        }
        for (dr, dc) in kingOffsets {
            let rr = r + dr, cc = c + dc
            if Square(r: rr, c: cc).inBounds(), let p = board[rr][cc], p.color == byColor, p.type == .king { return true }
        }
        let pawnDir = byColor == .white ? 1 : -1
        for dc in [-1, 1] {
            let rr = r + pawnDir, cc = c + dc
            if Square(r: rr, c: cc).inBounds(), let p = board[rr][cc], p.color == byColor, p.type == .pawn { return true }
        }
        for (dr, dc) in bishopDirs {
            var rr = r + dr, cc = c + dc
            while Square(r: rr, c: cc).inBounds() {
                if let p = board[rr][cc] {
                    if p.color == byColor, (p.type == .bishop || p.type == .queen) { return true }
                    break
                }
                rr += dr; cc += dc
            }
        }
        for (dr, dc) in rookDirs {
            var rr = r + dr, cc = c + dc
            while Square(r: rr, c: cc).inBounds() {
                if let p = board[rr][cc] {
                    if p.color == byColor, (p.type == .rook || p.type == .queen) { return true }
                    break
                }
                rr += dr; cc += dc
            }
        }
        return false
    }

    func isInCheck(_ color: PieceColor) -> Bool {
        guard let king = findKing(color) else { return false }
        return isSquareAttacked(king.r, king.c, by: color.opponent)
    }

    private func pseudoMoves(r: Int, c: Int) -> [Move] {
        guard let p = board[r][c] else { return [] }
        var moves: [Move] = []
        let from = Square(r: r, c: c)

        switch p.type {
        case .pawn:
            let dir = p.color == .white ? -1 : 1
            let startRow = p.color == .white ? 6 : 1
            let promoRow = p.color == .white ? 0 : 7
            let oneR = r + dir
            if Square(r: oneR, c: c).inBounds(), board[oneR][c] == nil {
                if oneR == promoRow {
                    for promo: PieceType in [.queen, .rook, .bishop, .knight] {
                        moves.append(Move(from: from, to: Square(r: oneR, c: c), piece: p, promotion: promo))
                    }
                } else {
                    moves.append(Move(from: from, to: Square(r: oneR, c: c), piece: p))
                    let twoR = r + dir * 2
                    if r == startRow, board[twoR][c] == nil {
                        moves.append(Move(from: from, to: Square(r: twoR, c: c), piece: p, doubleStep: true))
                    }
                }
            }
            for dc in [-1, 1] {
                let cc = c + dc
                guard Square(r: oneR, c: cc).inBounds() else { continue }
                if let target = board[oneR][cc], target.color != p.color {
                    if oneR == promoRow {
                        for promo: PieceType in [.queen, .rook, .bishop, .knight] {
                            moves.append(Move(from: from, to: Square(r: oneR, c: cc), piece: p, capture: true, promotion: promo))
                        }
                    } else {
                        moves.append(Move(from: from, to: Square(r: oneR, c: cc), piece: p, capture: true))
                    }
                } else if board[oneR][cc] == nil, let ep = enPassant, ep.r == oneR, ep.c == cc {
                    moves.append(Move(from: from, to: Square(r: oneR, c: cc), piece: p, capture: true, enPassant: true))
                }
            }
        case .knight:
            for (dr, dc) in knightOffsets {
                let rr = r + dr, cc = c + dc
                guard Square(r: rr, c: cc).inBounds() else { continue }
                if let target = board[rr][cc] {
                    if target.color != p.color { moves.append(Move(from: from, to: Square(r: rr, c: cc), piece: p, capture: true)) }
                } else {
                    moves.append(Move(from: from, to: Square(r: rr, c: cc), piece: p))
                }
            }
        case .king:
            for (dr, dc) in kingOffsets {
                let rr = r + dr, cc = c + dc
                guard Square(r: rr, c: cc).inBounds() else { continue }
                if let target = board[rr][cc] {
                    if target.color != p.color { moves.append(Move(from: from, to: Square(r: rr, c: cc), piece: p, capture: true)) }
                } else {
                    moves.append(Move(from: from, to: Square(r: rr, c: cc), piece: p))
                }
            }
            moves.append(contentsOf: castlingMoves(r: r, c: c, color: p.color, piece: p))
        default:
            let dirs = p.type == .bishop ? bishopDirs : (p.type == .rook ? rookDirs : bishopDirs + rookDirs)
            for (dr, dc) in dirs {
                var rr = r + dr, cc = c + dc
                while Square(r: rr, c: cc).inBounds() {
                    if let target = board[rr][cc] {
                        if target.color != p.color { moves.append(Move(from: from, to: Square(r: rr, c: cc), piece: p, capture: true)) }
                        break
                    } else {
                        moves.append(Move(from: from, to: Square(r: rr, c: cc), piece: p))
                    }
                    rr += dr; cc += dc
                }
            }
        }
        return moves
    }

    private func castlingMoves(r: Int, c: Int, color: PieceColor, piece: Piece) -> [Move] {
        guard !isInCheck(color) else { return [] }
        let rank = color == .white ? 7 : 0
        guard r == rank, c == 4 else { return [] }
        let opp = color.opponent
        var moves: [Move] = []

        let kingSide = color == .white ? castling.wK : castling.bK
        if kingSide, board[rank][5] == nil, board[rank][6] == nil,
           let rook = board[rank][7], rook.type == .rook, rook.color == color,
           !isSquareAttacked(rank, 5, by: opp), !isSquareAttacked(rank, 6, by: opp) {
            moves.append(Move(from: Square(r: r, c: c), to: Square(r: rank, c: 6), piece: piece, castle: "K"))
        }
        let queenSide = color == .white ? castling.wQ : castling.bQ
        if queenSide, board[rank][3] == nil, board[rank][2] == nil, board[rank][1] == nil,
           let rook = board[rank][0], rook.type == .rook, rook.color == color,
           !isSquareAttacked(rank, 3, by: opp), !isSquareAttacked(rank, 2, by: opp) {
            moves.append(Move(from: Square(r: r, c: c), to: Square(r: rank, c: 2), piece: piece, castle: "Q"))
        }
        return moves
    }

    @discardableResult
    private func applyMoveRaw(_ move: Move) -> Piece? {
        let piece = board[move.from.r][move.from.c]!
        let captured = board[move.to.r][move.to.c]

        board[move.to.r][move.to.c] = Piece(type: move.promotion ?? piece.type, color: piece.color)
        board[move.from.r][move.from.c] = nil

        if move.enPassant {
            let capR = piece.color == .white ? move.to.r + 1 : move.to.r - 1
            board[capR][move.to.c] = nil
        }
        if move.castle == "K" {
            let rank = move.from.r
            board[rank][5] = board[rank][7]
            board[rank][7] = nil
        } else if move.castle == "Q" {
            let rank = move.from.r
            board[rank][3] = board[rank][0]
            board[rank][0] = nil
        }
        return captured
    }

    private func legalMoves(r: Int, c: Int) -> [Move] {
        guard let p = board[r][c] else { return [] }
        let pseudo = pseudoMoves(r: r, c: c)
        var legal: [Move] = []
        for move in pseudo {
            let savedBoard = board
            let savedCastling = castling
            let savedEnPassant = enPassant
            applyMoveRaw(move)
            let stillInCheck = isInCheck(p.color)
            board = savedBoard
            castling = savedCastling
            enPassant = savedEnPassant
            if !stillInCheck { legal.append(move) }
        }
        return legal
    }

    func legalMoves(from square: Square) -> [Move] {
        guard let p = board[square.r][square.c], p.color == turn, !isGameOver else { return [] }
        return legalMoves(r: square.r, c: square.c)
    }

    func allLegalMoves(for color: PieceColor? = nil) -> [Move] {
        let side = color ?? turn
        if isGameOver { return [] }
        var moves: [Move] = []
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == side { moves.append(contentsOf: legalMoves(r: r, c: c)) }
            }
        }
        return moves
    }

    private func san(for move: Move, legalMovesThisTurn: [Move]) -> String {
        if move.castle == "K" { return "O-O" }
        if move.castle == "Q" { return "O-O-O" }
        let p = move.piece
        let dest = move.to.name

        if p.type == .pawn {
            var s = ""
            if move.capture { s += String(Array("abcdefgh")[move.from.c]) + "x" }
            s += dest
            if let promo = move.promotion { s += "=" + promo.rawValue.uppercased() }
            return s
        }

        let letter = p.type.rawValue.uppercased()
        let ambiguous = legalMovesThisTurn.filter { $0 != move && $0.piece.type == p.type && $0.to == move.to }
        var disambig = ""
        if !ambiguous.isEmpty {
            let sameFile = ambiguous.contains { $0.from.c == move.from.c }
            let sameRank = ambiguous.contains { $0.from.r == move.from.r }
            if !sameFile { disambig = String(Array("abcdefgh")[move.from.c]) }
            else if !sameRank { disambig = "\(8 - move.from.r)" }
            else { disambig = move.from.name }
        }
        return "\(letter)\(disambig)\(move.capture ? "x" : "")\(dest)"
    }

    @discardableResult
    func makeMove(from: Square, to: Square, promotion: PieceType? = nil) -> MoveRecord? {
        if isGameOver { return nil }
        let legalNow = allLegalMoves(for: turn)
        guard let match = legalNow.first(where: { $0.from == from && $0.to == to && $0.promotion == promotion }) else { return nil }

        let sanBase = san(for: match, legalMovesThisTurn: legalNow)
        let piece = board[match.from.r][match.from.c]!
        let isPawnMove = piece.type == .pawn
        let captured = applyMoveRaw(match)

        if piece.type == .king {
            if piece.color == .white { castling.wK = false; castling.wQ = false }
            else { castling.bK = false; castling.bQ = false }
        }
        if piece.type == .rook {
            if match.from.r == 7, match.from.c == 0 { castling.wQ = false }
            if match.from.r == 7, match.from.c == 7 { castling.wK = false }
            if match.from.r == 0, match.from.c == 0 { castling.bQ = false }
            if match.from.r == 0, match.from.c == 7 { castling.bK = false }
        }
        if let captured, captured.type == .rook {
            if match.to.r == 7, match.to.c == 0 { castling.wQ = false }
            if match.to.r == 7, match.to.c == 7 { castling.wK = false }
            if match.to.r == 0, match.to.c == 0 { castling.bQ = false }
            if match.to.r == 0, match.to.c == 7 { castling.bK = false }
        }

        enPassant = match.doubleStep ? Square(r: (match.from.r + match.to.r) / 2, c: match.from.c) : nil
        halfmoveClock = (isPawnMove || captured != nil || match.enPassant) ? 0 : halfmoveClock + 1
        if turn == .black { fullmoveNumber += 1 }

        let movedColor = turn
        turn = turn.opponent
        recordPosition()

        let nextMoves = allLegalMoves(for: turn)
        let inCheck = isInCheck(turn)
        var sanFinal = sanBase
        var status = "ok"
        if nextMoves.isEmpty {
            if inCheck {
                sanFinal += "#"
                result = .checkmate
                winner = movedColor
                status = "checkmate"
            } else {
                result = .stalemate
                status = "stalemate"
            }
        } else if inCheck {
            sanFinal += "+"
            status = "check"
        }

        if !isGameOver {
            if halfmoveClock >= 100 { result = .draw50; status = "draw" }
            else if (positionCounts[positionKey()] ?? 0) >= 3 { result = .drawRepetition; status = "draw" }
            else if isInsufficientMaterial() { result = .drawMaterial; status = "draw" }
        }

        let record = MoveRecord(san: sanFinal, from: match.from, to: match.to, piece: piece.type, color: movedColor,
                                 capture: captured != nil || match.enPassant, promotion: match.promotion, castle: match.castle, status: status)
        history.append(record)
        return record
    }

    private func isInsufficientMaterial() -> Bool {
        var pieces: [Piece] = []
        for r in 0..<8 { for c in 0..<8 { if let p = board[r][c] { pieces.append(p) } } }
        if pieces.count > 4 { return false }
        let nonKings = pieces.filter { $0.type != .king }
        if nonKings.isEmpty { return true }
        if nonKings.count == 1, (nonKings[0].type == .bishop || nonKings[0].type == .knight) { return true }
        if nonKings.count == 2, nonKings.allSatisfy({ $0.type == .bishop }) { return true }
        return false
    }

    func gameStatusText() -> GameStatus {
        switch result {
        case .checkmate: return GameStatus(over: true, key: "checkmate", winner: winner)
        case .stalemate: return GameStatus(over: true, key: "stalemate", winner: nil)
        case .draw50: return GameStatus(over: true, key: "draw50", winner: nil)
        case .drawRepetition: return GameStatus(over: true, key: "drawRepetition", winner: nil)
        case .drawMaterial: return GameStatus(over: true, key: "drawMaterial", winner: nil)
        case .none:
            if isInCheck(turn) { return GameStatus(over: false, key: "check", winner: nil) }
            return GameStatus(over: false, key: "playing", winner: nil)
        }
    }
}
