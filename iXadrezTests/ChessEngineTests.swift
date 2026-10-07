import XCTest
@testable import iXadrez

/// Perft counts every legal move tree to a fixed depth from well-known positions and compares
/// against published totals — it catches castling, en passant, promotion and pin bugs at once.
/// The same positions are checked by the web (tests/engine.test.js) and Android ports.
final class ChessEngineTests: XCTestCase {
    private func sq(_ s: String) -> Square {
        let chars = Array(s)
        return Square(r: 8 - Int(String(chars[1]))!, c: Array("abcdefgh").firstIndex(of: chars[0])!)
    }

    private func fromFen(_ fen: String) -> ChessGame {
        let parts = fen.split(separator: " ").map(String.init)
        var board: Board = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        for (r, row) in parts[0].split(separator: "/").enumerated() {
            var c = 0
            for ch in row {
                if let n = ch.wholeNumberValue {
                    c += n
                } else {
                    board[r][c] = Piece(type: PieceType(rawValue: String(ch).lowercased())!, color: ch.isUppercase ? .white : .black)
                    c += 1
                }
            }
        }
        let g = ChessGame()
        g.board = board
        g.turn = parts[1] == "w" ? .white : .black
        let cs = parts[2]
        g.castling = CastlingRights(wK: cs.contains("K"), wQ: cs.contains("Q"), bK: cs.contains("k"), bQ: cs.contains("q"))
        g.enPassant = parts[3] == "-" ? nil : sq(parts[3])
        g.history = []
        return g
    }

    private func perft(_ game: ChessGame, _ depth: Int) -> Int {
        let moves = game.allLegalMoves(for: game.turn)
        if depth == 1 { return moves.count }
        var nodes = 0
        for m in moves {
            let child = game.clone()
            _ = child.makeMove(from: m.from, to: m.to, promotion: m.promotion)
            child.result = nil // draws end a real game, but perft must keep counting
            nodes += perft(child, depth - 1)
        }
        return nodes
    }

    private func assertPerft(_ fen: String, _ counts: [Int], file: StaticString = #filePath, line: UInt = #line) {
        for (i, expected) in counts.enumerated() {
            XCTAssertEqual(perft(fromFen(fen), i + 1), expected, "perft \(i + 1) \(fen)", file: file, line: line)
        }
    }

    func testPerftStartPosition() { assertPerft("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", [20, 400, 8902]) }
    func testPerftKiwipete() { assertPerft("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", [48, 2039]) }
    func testPerftEndgame() { assertPerft("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", [14, 191, 2812]) }
    func testPerftPromotions() { assertPerft("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", [6, 264, 9467]) }
    func testPerftPosition5() { assertPerft("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", [44, 1486]) }

    /// Each position becomes K+minors vs K after the white king captures the rook on d2.
    private func resultAfterKxd2(_ fen: String) -> GameResult? {
        let g = fromFen(fen)
        _ = g.makeMove(from: sq("e1"), to: sq("d2"))
        return g.result
    }

    func testInsufficientMaterial() {
        XCTAssertNil(resultAfterKxd2("4k3/8/8/8/8/8/3r4/2B1KB2 w - - 0 1")) // bishops on both colours mate
        XCTAssertEqual(resultAfterKxd2("4kb2/8/8/8/8/8/3r4/2B1K3 w - - 0 1"), .drawMaterial) // same colour
        XCTAssertNil(resultAfterKxd2("2b1k3/8/8/8/8/8/3r4/2B1K3 w - - 0 1")) // opposite colours
        XCTAssertEqual(resultAfterKxd2("4k3/8/8/8/8/8/3r4/1N2K3 w - - 0 1"), .drawMaterial) // lone knight
    }

    func testThreefoldRepetitionIgnoresUnusableEnPassantSquare() {
        let g = ChessGame()
        for (a, b) in [("e2", "e4"), ("g8", "f6"), ("g1", "f3"), ("f6", "g8"), ("f3", "g1"),
                       ("g8", "f6"), ("g1", "f3"), ("f6", "g8"), ("f3", "g1")] {
            _ = g.makeMove(from: sq(a), to: sq(b))
        }
        XCTAssertEqual(g.result, .drawRepetition)
    }

    func testFoolsMate() {
        let g = ChessGame()
        for (a, b) in [("f2", "f3"), ("e7", "e5"), ("g2", "g4"), ("d8", "h4")] { _ = g.makeMove(from: sq(a), to: sq(b)) }
        XCTAssertEqual(g.result, .checkmate)
        XCTAssertEqual(g.winner, .black)
        XCTAssertEqual(g.history.last?.san, "Qh4#")
    }

    func testBotFindsMateInOne() {
        let g = fromFen("r3k3/8/8/8/8/8/5PPP/6K1 b - - 0 1")
        for level in [BotDifficulty.medium, .hard] {
            XCTAssertEqual(ChessAI.pickMove(game: g, difficulty: level)?.to, sq("a1"), "bot \(level)")
        }
    }
}
