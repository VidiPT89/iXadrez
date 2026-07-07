import SwiftUI

private let pieceGlyph: [PieceType: String] = [
    .king: "♚", .queen: "♛", .rook: "♜", .bishop: "♝", .knight: "♞", .pawn: "♟",
]

/// Reusable 8x8 board renderer, shared by the main game screen and the tutorial lessons.
struct ChessBoardView: View {
    let board: Board
    var selected: Square? = nil
    var legalTargets: [Move] = []
    var lastMove: (from: Square, to: Square)? = nil
    var checkSquare: Square? = nil
    var flipped: Bool = false
    var onTap: (Square) -> Void = { _ in }

    private let goldColor = Color(red: 0.83, green: 0.69, blue: 0.22)
    private let squareLight = Color(red: 0.93, green: 0.87, blue: 0.77)
    private let squareDark = Color(red: 0.42, green: 0.29, blue: 0.20)

    private func displayCoord(_ r: Int, _ c: Int) -> (Int, Int) {
        flipped ? (7 - r, 7 - c) : (r, c)
    }

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
                                squareView(r: r, c: c, cellSize: cell)
                            }
                        }
                    }
                }
            }
            .frame(width: size, height: size)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(goldColor, lineWidth: 3))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func squareView(r: Int, c: Int, cellSize: CGFloat) -> some View {
        let isLight = (r + c) % 2 == 0
        let piece = board[r][c]
        let sq = Square(r: r, c: c)
        let isSelected = selected == sq
        let isLast = lastMove.map { $0.from == sq || $0.to == sq } ?? false
        let isCheck = checkSquare == sq
        let target = legalTargets.first { $0.to == sq }

        ZStack {
            (isLight ? squareLight : squareDark)

            if isSelected {
                Rectangle().stroke(goldColor, lineWidth: 4)
            } else if isCheck {
                Rectangle().stroke(Color(red: 0.75, green: 0.31, blue: 0.25), lineWidth: 4)
            } else if isLast {
                Rectangle().stroke(goldColor.opacity(0.5), lineWidth: 4)
            }

            if let piece {
                Text(pieceGlyph[piece.type] ?? "")
                    .font(.system(size: cellSize * 0.68))
                    .foregroundColor(piece.color == .white ? Color(white: 0.98) : Color(white: 0.08))
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }

            if let target {
                if target.capture {
                    Circle().stroke(Color(red: 0.75, green: 0.31, blue: 0.25), lineWidth: 4).padding(cellSize * 0.08)
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
