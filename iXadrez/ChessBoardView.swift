import SwiftUI

let pieceImageName: [PieceType: String] = [
    .king: "piece_k", .queen: "piece_q", .rook: "piece_r",
    .bishop: "piece_b", .knight: "piece_n", .pawn: "piece_p",
]

let whitePieceGradient = LinearGradient(
    colors: [Color(red: 0.992, green: 0.976, blue: 0.933), Color(red: 0.914, green: 0.788, blue: 0.416)],
    startPoint: .top, endPoint: .bottom
)
let blackPieceGradient = LinearGradient(
    colors: [Color(red: 0.227, green: 0.188, blue: 0.125), Color(red: 0.051, green: 0.043, blue: 0.024)],
    startPoint: .top, endPoint: .bottom
)

/// A single on-board piece with a stable identity, so SwiftUI can animate it sliding
/// from its old square to its new one instead of popping in and out.
struct PieceInstance: Identifiable, Equatable {
    let id: UUID
    var type: PieceType
    let color: PieceColor
    var square: Square

    static func fresh(from board: Board) -> [PieceInstance] {
        var result: [PieceInstance] = []
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c] {
                    result.append(PieceInstance(id: UUID(), type: p.type, color: p.color, square: Square(r: r, c: c)))
                }
            }
        }
        return result
    }
}

/// Reusable 8x8 board renderer, shared by the main game screen and the tutorial lessons.
struct ChessBoardView: View {
    let pieces: [PieceInstance]
    var selected: Square? = nil
    var legalTargets: [Move] = []
    var lastMove: (from: Square, to: Square)? = nil
    var checkSquare: Square? = nil
    var flipped: Bool = false
    var onTap: (Square) -> Void = { _ in }

    private let goldColor = Theme.gold

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cell = size / 8

            ZStack {
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { displayRow in
                        HStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { displayCol in
                                let (r, c) = flipped ? (7 - displayRow, 7 - displayCol) : (displayRow, displayCol)
                                squareBackground(r: r, c: c, cellSize: cell)
                            }
                        }
                    }
                }

                ForEach(pieces) { piece in
                    pieceView(piece, cellSize: cell)
                        .position(position(for: piece.square, cellSize: cell))
                }
            }
            .frame(width: size, height: size)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(goldColor, lineWidth: 3))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func position(for square: Square, cellSize: CGFloat) -> CGPoint {
        let (r, c) = flipped ? (7 - square.r, 7 - square.c) : (square.r, square.c)
        return CGPoint(x: (CGFloat(c) + 0.5) * cellSize, y: (CGFloat(r) + 0.5) * cellSize)
    }

    @ViewBuilder
    private func pieceView(_ piece: PieceInstance, cellSize: CGFloat) -> some View {
        Image(pieceImageName[piece.type] ?? "piece_p")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(piece.color == .white ? whitePieceGradient : blackPieceGradient)
            .shadow(color: .black.opacity(0.55), radius: 1.5, x: 0, y: 2)
            .padding(cellSize * 0.13)
            .frame(width: cellSize, height: cellSize)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func squareBackground(r: Int, c: Int, cellSize: CGFloat) -> some View {
        let isLight = (r + c) % 2 == 0
        let sq = Square(r: r, c: c)
        let isSelected = selected == sq
        let isLast = lastMove.map { $0.from == sq || $0.to == sq } ?? false
        let isCheck = checkSquare == sq
        let target = legalTargets.first { $0.to == sq }

        ZStack {
            LinearGradient(
                colors: isLight ? [Theme.squareLight, Theme.squareLight2] : [Theme.squareDark, Theme.squareDark2],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            if isSelected {
                Rectangle().stroke(goldColor, lineWidth: 4)
            } else if isCheck {
                Rectangle().stroke(Theme.danger, lineWidth: 4)
            } else if isLast {
                Rectangle().stroke(goldColor.opacity(0.5), lineWidth: 4)
            }

            if let target {
                if target.capture {
                    Circle().stroke(Theme.danger, lineWidth: 4).padding(cellSize * 0.08)
                } else {
                    Circle().fill(goldColor.opacity(0.55)).frame(width: cellSize * 0.26, height: cellSize * 0.26)
                }
            }
        }
        .frame(width: cellSize, height: cellSize)
        .contentShape(Rectangle())
        .onTapGesture { onTap(sq) }
    }
}
