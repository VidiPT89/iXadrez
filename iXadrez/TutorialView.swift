import SwiftUI

private struct Lesson {
    let titlePt: String, titleEn: String
    let textPt: String, textEn: String
    let setup: () -> ChessGame

    func title(_ lang: AppLanguage) -> String { lang == .pt ? titlePt : titleEn }
    func text(_ lang: AppLanguage) -> String { lang == .pt ? textPt : textEn }
}

private func customGame(_ pieces: [(String, PieceType, PieceColor)], turn: PieceColor = .white) -> ChessGame {
    var board: Board = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    let files = Array("abcdefgh")
    for (square, type, color) in pieces {
        let chars = Array(square)
        let file = files.firstIndex(of: chars[0])!
        let rank = 8 - Int(String(chars[1]))!
        board[rank][file] = Piece(type: type, color: color)
    }
    let g = ChessGame()
    g.board = board
    g.turn = turn
    g.castling = CastlingRights(wK: false, wQ: false, bK: false, bQ: false)
    g.enPassant = nil
    g.history = []
    return g
}

private let lessons: [Lesson] = [
    Lesson(
        titlePt: "1. Como as peças se movem", titleEn: "1. How the pieces move",
        textPt: "Cada peça move-se de forma diferente. O peão avança uma casa (duas no primeiro lance) e captura na diagonal. O cavalo salta em 'L'. O bispo move-se na diagonal. A torre move-se em linha reta. A dama combina torre e bispo. O rei move-se uma casa em qualquer direção.\n\nToca numa peça do tabuleiro para veres exatamente para onde ela pode ir.",
        textEn: "Every piece moves differently. The pawn advances one square (two on its first move) and captures diagonally. The knight jumps in an 'L' shape. The bishop moves diagonally. The rook moves in straight lines. The queen combines rook and bishop. The king moves one square in any direction.\n\nTap a piece on the board to see exactly where it can go.",
        setup: { customGame([("d4", .knight, .white), ("b6", .bishop, .white), ("g2", .rook, .white), ("a2", .pawn, .white), ("f6", .queen, .black), ("e8", .king, .black)]) }
    ),
    Lesson(
        titlePt: "2. Regras especiais", titleEn: "2. Special rules",
        textPt: "O roque move o rei duas casas em direção à torre (e a torre salta para o outro lado do rei), desde que nenhum dos dois se tenha mexido e as casas entre eles estejam livres e fora de ataque.\n\nO en passant permite a um peão capturar um peão adversário que acabou de avançar duas casas, como se tivesse avançado só uma.\n\nUm peão que chega à última fileira é promovido — normalmente a dama.\n\nXeque é quando o rei está sob ataque; xeque-mate é quando não há forma de escapar; afogamento é quando o jogador não tem lances legais mas não está em xeque — resulta em empate.",
        textEn: "Castling moves the king two squares toward a rook (and the rook jumps to the other side of the king), as long as neither has moved and the squares between them are empty and not under attack.\n\nEn passant lets a pawn capture an enemy pawn that just advanced two squares, as if it had only moved one.\n\nA pawn reaching the last rank is promoted — usually to a queen.\n\nCheck is when the king is under attack; checkmate is when there is no way to escape; stalemate is when a player has no legal move but isn't in check — the game is a draw.",
        setup: { customGame([("e1", .king, .white), ("h1", .rook, .white), ("a1", .rook, .white), ("e8", .king, .black)]) }
    ),
    Lesson(
        titlePt: "3. Princípios de abertura", titleEn: "3. Opening principles",
        textPt: "Controla o centro (casas d4, d5, e4, e5) com peões e peças. Desenvolve cavalos e bispos cedo, antes da dama. Roca cedo para pores o rei em segurança. Evita mover a mesma peça várias vezes na abertura e não saias com a dama demasiado cedo — ela pode ser atacada e perder tempo.",
        textEn: "Control the center (the d4, d5, e4, e5 squares) with pawns and pieces. Develop knights and bishops early, before the queen. Castle early to keep your king safe. Avoid moving the same piece multiple times in the opening, and don't bring your queen out too soon — it can be attacked and lose you tempo.",
        setup: { customGame([("e4", .pawn, .white), ("c3", .knight, .white), ("f3", .knight, .white), ("e1", .king, .white), ("e5", .pawn, .black), ("c6", .knight, .black), ("f6", .knight, .black), ("e8", .king, .black)]) }
    ),
    Lesson(
        titlePt: "4. Táticas básicas", titleEn: "4. Basic tactics",
        textPt: "Garfo: uma peça ataca duas peças adversárias ao mesmo tempo (o cavalo é excelente nisto). Cravo: uma peça não se pode mover porque exporia uma peça mais valiosa atrás dela. Espeto: como o cravo, mas a peça mais valiosa está à frente e é forçada a mover-se, expondo a de trás. Ataque descoberto: mover uma peça revela o ataque de outra peça escondida atrás.\n\nToca no cavalo para veres um exemplo de garfo neste tabuleiro.",
        textEn: "Fork: one piece attacks two enemy pieces at once (the knight is excellent at this). Pin: a piece can't move because it would expose a more valuable piece behind it. Skewer: like a pin, but the more valuable piece is in front and forced to move, exposing the one behind it. Discovered attack: moving one piece reveals an attack from another piece hidden behind it.\n\nTap the knight to see a fork example on this board.",
        setup: { customGame([("e5", .knight, .white), ("d7", .king, .black), ("f7", .rook, .black)]) }
    ),
    Lesson(
        titlePt: "5. Finais básicos", titleEn: "5. Basic endgames",
        textPt: "Com rei e dama contra rei sozinho, encurrala o rei adversário para a margem do tabuleiro usando a dama a uma 'distância de cavalo', trazendo o teu rei para ajudar a dar o mate.\n\nOposição: em finais de rei e peão, ter o teu rei diretamente à frente do rei adversário (com uma casa de intervalo) força-o a recuar.\n\nUm peão passado (sem peões adversários a travá-lo nas colunas vizinhas) é um trunfo enorme — protege-o e empurra-o para promoção.",
        textEn: "With king and queen versus a lone king, herd the enemy king to the edge of the board using the queen at a 'knight's distance', and bring your own king up to help deliver mate.\n\nOpposition: in king-and-pawn endgames, having your king directly facing the enemy king (with one square between them) forces it to give way.\n\nA passed pawn (with no enemy pawns able to stop it on neighboring files) is a huge asset — protect it and push it toward promotion.",
        setup: { customGame([("e1", .king, .white), ("d5", .queen, .white), ("e8", .king, .black)]) }
    ),
]

struct TutorialView: View {
    @ObservedObject var loc = Loc.shared
    var onBackToMenu: () -> Void

    @State private var index = 0
    @State private var game = lessons[0].setup()
    @State private var selected: Square? = nil
    @State private var legalTargets: [Move] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    ForEach(0..<lessons.count, id: \.self) { i in
                        Button {
                            select(i)
                        } label: {
                            Text("\(i + 1)")
                                .font(Theme.sora(14, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(i == index ? Theme.gold : Theme.panel).overlay(Circle().stroke(Theme.panelBorder, lineWidth: 1)))
                                .foregroundColor(i == index ? Theme.bg : Theme.ink)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(lessons[index].title(loc.language))
                        .font(Theme.soraExtraBold(20))
                        .foregroundColor(Theme.goldSoft)
                    Text(lessons[index].text(loc.language))
                        .font(Theme.sora(14))
                        .foregroundColor(Theme.inkDim)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panel).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.panelBorder, lineWidth: 1)))

                ChessBoardView(
                    pieces: PieceInstance.fresh(from: game.board),
                    selected: selected,
                    legalTargets: legalTargets,
                    onTap: tap
                )
                .frame(width: 320, height: 320)

                Text(loc.t("lessonHintClick")).font(Theme.sora(13)).foregroundColor(Theme.goldSoft)

                HStack(spacing: 10) {
                    Button(loc.t("prevLesson")) { select(index - 1) }.buttonStyle(GhostButtonStyle()).disabled(index == 0)
                    Button(loc.t("nextLesson")) { select(index + 1) }.buttonStyle(GhostButtonStyle()).disabled(index == lessons.count - 1)
                    Button(loc.t("backToMenu")) { onBackToMenu() }.buttonStyle(GhostButtonStyle())
                }
            }
            .padding(20)
        }
    }

    private func select(_ newIndex: Int) {
        guard newIndex >= 0, newIndex < lessons.count else { return }
        index = newIndex
        game = lessons[index].setup()
        selected = nil
        legalTargets = []
    }

    private func tap(_ square: Square) {
        if let sel = selected, legalTargets.contains(where: { $0.to == square }) {
            _ = game.makeMove(from: sel, to: square)
            selected = nil
            legalTargets = []
            return
        }
        if let piece = game.pieceAt(square.r, square.c), piece.color == game.turn {
            selected = square
            legalTargets = game.legalMoves(from: square)
        } else {
            selected = nil
            legalTargets = []
        }
    }
}
