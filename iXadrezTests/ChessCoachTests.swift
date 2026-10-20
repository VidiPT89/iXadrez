import XCTest
@testable import iXadrez

final class ChessCoachTests: XCTestCase {
    private func sq(_ s: String) -> Square {
        let chars = Array(s)
        return Square(r: 8 - Int(String(chars[1]))!, c: Array("abcdefgh").firstIndex(of: chars[0])!)
    }

    private func play(_ moves: [(String, String)]) -> [MoveRecord] {
        let g = ChessGame()
        for (a, b) in moves { XCTAssertNotNil(g.makeMove(from: sq(a), to: sq(b)), "\(a)\(b)") }
        return g.history
    }

    func testGradeThresholds() {
        XCTAssertEqual(ChessCoach.grade(loss: 500, playedBest: true), .best)
        XCTAssertEqual(ChessCoach.grade(loss: 5, playedBest: false), .best)
        XCTAssertEqual(ChessCoach.grade(loss: 30, playedBest: false), .good)
        XCTAssertEqual(ChessCoach.grade(loss: 80, playedBest: false), .inaccuracy)
        XCTAssertEqual(ChessCoach.grade(loss: 200, playedBest: false), .mistake)
        XCTAssertEqual(ChessCoach.grade(loss: 900, playedBest: false), .blunder)
    }

    func testAccuracyDropsWithLoss() {
        XCTAssertEqual(ChessCoach.moveAccuracy(before: 50, after: 50), 100, accuracy: 0.5)
        XCTAssertGreaterThan(ChessCoach.moveAccuracy(before: 50, after: 0), ChessCoach.moveAccuracy(before: 50, after: -400))
    }

    /// Scholar's mate: Black's ...Nf6 walks into Qxf7#, which the Coach must flag as allowing mate.
    func testFlagsAllowedMateAndPraisesTheMate() {
        let records = play([("e2", "e4"), ("e7", "e5"), ("f1", "c4"), ("b8", "c6"), ("d1", "h5"), ("g8", "f6"), ("h5", "f7")])
        let report = ChessCoach.review(records)
        XCTAssertEqual(report.moves.count, 7)
        XCTAssertEqual(report.boards.count, 8)
        let nf6 = report.moves[5]
        XCTAssertEqual(nf6.quality, .blunder)
        XCTAssertEqual(nf6.theme, .allowedMate)
        XCTAssertNotNil(nf6.bestFrom)
        XCTAssertTrue(nf6.textPt.contains("Qxf7#") || nf6.textPt.contains("mate"))
        let mate = report.moves[6]
        XCTAssertEqual(mate.quality, .best)
        XCTAssertTrue(mate.textPt.hasPrefix("Xeque-mate"))
        XCTAssertGreaterThan(report.accuracyWhite, report.accuracyBlack)
    }

    /// 3...Qg5 puts the queen where the f3 knight takes it for free.
    func testFlagsHangingQueen() {
        let records = play([("e2", "e4"), ("e7", "e5"), ("g1", "f3"), ("d8", "g5")])
        let report = ChessCoach.review(records)
        for sound in report.moves.prefix(3) {
            XCTAssertLessThan(sound.quality, .inaccuracy, "\(sound.record.san) is a normal opening move")
        }
        let qg5 = report.moves[3]
        XCTAssertGreaterThanOrEqual(qg5.quality, .mistake)
        XCTAssertEqual(qg5.theme, .hangingPiece)
        XCTAssertTrue(qg5.textPt.contains("A dama em g5"), qg5.textPt)
        XCTAssertTrue(qg5.textPt.contains("Cxg5"), qg5.textPt)
        XCTAssertTrue(qg5.textEn.contains("queen on g5"), qg5.textEn)
    }

    func testMissedFreeQueenIsFlagged() {
        // After 3...Qg5 White plays a quiet move instead of Nxg5.
        let records = play([("e2", "e4"), ("e7", "e5"), ("g1", "f3"), ("d8", "g5"), ("a2", "a3")])
        let a3 = ChessCoach.review(records).moves[4]
        XCTAssertEqual(a3.quality, .blunder)
        XCTAssertEqual(a3.theme, .missedCapture)
        XCTAssertTrue(a3.textPt.contains("a dama em g5"), a3.textPt)
    }

    func testPortugueseNotation() {
        XCTAssertEqual(sanText("Nxg5", .pt), "Cxg5")
        XCTAssertEqual(sanText("Qxf7#", .pt), "Dxf7#")
        XCTAssertEqual(sanText("Rae1", .pt), "Tae1")
        XCTAssertEqual(sanText("Kf1", .pt), "Rf1")
        XCTAssertEqual(sanText("exd8=Q+", .pt), "exd8=D+")
        XCTAssertEqual(sanText("O-O-O", .pt), "O-O-O")
        XCTAssertEqual(sanText("Nxg5", .en), "Nxg5")
    }

    func testEncodeDecodeRoundTrip() {
        let records = play([("e2", "e4"), ("e7", "e5"), ("g1", "f3"), ("b8", "c6")])
        let encoded = CoachStore.encode(records)
        XCTAssertEqual(encoded, "e2e4,e7e5,g1f3,b8c6")
        XCTAssertEqual(CoachStore.decode(encoded).map(\.san), records.map(\.san))
        XCTAssertEqual(CoachStore.decode("e2e4,zz99,e7e5").count, 1)
    }
}
