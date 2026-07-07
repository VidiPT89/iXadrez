import SwiftUI

struct GameView: View {
    @ObservedObject var vm: GameViewModel
    @ObservedObject var loc = Loc.shared
    var onBackToMenu: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                playerTag(color: .black)

                ChessBoardView(
                    board: vm.game.board,
                    selected: vm.selected,
                    legalTargets: vm.legalTargets,
                    lastMove: vm.lastMove,
                    checkSquare: vm.isKingInCheckSquare(),
                    flipped: vm.flipped,
                    onTap: { vm.tapSquare($0) }
                )
                .frame(width: boardSize, height: boardSize)

                playerTag(color: .white)

                statusCard
                historyCard

                HStack(spacing: 10) {
                    Button(loc.t("flipBoard")) { vm.flipBoard() }.buttonStyle(GhostButtonStyle())
                    Button(loc.t("newGame")) { vm.newGame(mode: vm.mode, level: vm.botLevel) }.buttonStyle(GhostButtonStyle())
                    Button(loc.t("backToMenu")) { onBackToMenu() }.buttonStyle(GhostButtonStyle())
                }
            }
            .padding(20)
        }
        .sheet(item: promotionSheetBinding) { _ in
            promotionSheet
        }
        .sheet(isPresented: $vm.showResult) {
            resultSheet
        }
    }

    private var boardSize: CGFloat {
        min(UIScreen.main.bounds.width - 40, 460)
    }

    private func playerTag(color: PieceColor) -> some View {
        let active = vm.game.turn == color && !vm.statusText.over
        return Text(color == .white ? loc.t("whitePlayer") : loc.t("blackPlayer"))
            .font(Theme.sora(14, weight: .semibold))
            .padding(.horizontal, 16).padding(.vertical, 6)
            .background(Capsule().fill(Theme.panel).overlay(Capsule().stroke(active ? Theme.gold : Theme.panelBorder, lineWidth: 1)))
            .foregroundColor(active ? Theme.goldSoft : Theme.ink)
    }

    private var statusCard: some View {
        VStack(spacing: 4) {
            Text(vm.game.turn == .white ? loc.t("turnWhite") : loc.t("turnBlack"))
                .font(Theme.sora(17, weight: .bold))
                .foregroundColor(Theme.ink)
            let note: String = vm.thinking ? loc.t("thinking") : (vm.statusText.key == "check" ? loc.t("inCheck") : "")
            if !note.isEmpty {
                Text(note).font(Theme.sora(14)).foregroundColor(Theme.goldSoft)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panel).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.panelBorder, lineWidth: 1)))
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(loc.t("moveHistory")).font(Theme.sora(12, weight: .bold)).foregroundColor(Theme.inkDim).textCase(.uppercase)
            let history = vm.game.history
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<((history.count + 1) / 2), id: \.self) { i in
                        let white = history[i * 2]
                        let black = i * 2 + 1 < history.count ? history[i * 2 + 1] : nil
                        Text("\(i + 1). \(white.san)\(black != nil ? "   " + black!.san : "")")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(Theme.ink)
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panel).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.panelBorder, lineWidth: 1)))
    }

    // MARK: Promotion sheet

    private struct PromoIdentifiable: Identifiable { let id = 0 }
    private var promotionSheetBinding: Binding<PromoIdentifiable?> {
        Binding(
            get: { vm.promotionCandidates != nil ? PromoIdentifiable() : nil },
            set: { if $0 == nil { vm.promotionCandidates = nil } }
        )
    }

    private var promotionSheet: some View {
        VStack(spacing: 20) {
            Text(loc.t("promoTitle")).font(.headline).foregroundColor(Theme.ink)
            HStack(spacing: 16) {
                ForEach([PieceType.queen, .rook, .bishop, .knight], id: \.self) { type in
                    Button {
                        vm.choosePromotion(type)
                    } label: {
                        Image(pieceImageName[type] ?? "piece_q")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(vm.game.turn == .white ? whitePieceGradient : blackPieceGradient)
                            .shadow(color: .black.opacity(0.5), radius: 1.5, x: 0, y: 2)
                            .padding(12)
                            .frame(width: 64, height: 64)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bgSoft).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.panelBorder, lineWidth: 1)))
                    }
                }
            }
        }
        .padding(32)
        .presentationDetents([.height(180)])
    }

    // MARK: Result sheet

    private var resultSheet: some View {
        let status = vm.statusText
        var icon = "🤝"
        var title = ""
        var text = ""
        if status.key == "checkmate" {
            icon = "🏆"
            title = loc.t("resultCheckmateTitle")
            text = status.winner == .white ? loc.t("resultCheckmateWhite") : loc.t("resultCheckmateBlack")
        } else if status.key == "stalemate" {
            title = loc.t("resultStalemateTitle"); text = loc.t("resultStalemateText")
        } else if vm.game.result == .draw50 {
            title = loc.t("resultDraw50Title"); text = loc.t("resultDraw50Text")
        } else if vm.game.result == .drawRepetition {
            title = loc.t("resultDrawRepTitle"); text = loc.t("resultDrawRepText")
        } else {
            title = loc.t("resultDrawMatTitle"); text = loc.t("resultDrawMatText")
        }

        return VStack(spacing: 16) {
            Text(icon).font(Theme.sora(44))
            Text(title).font(Theme.sora(22, weight: .bold)).foregroundColor(Theme.goldSoft)
            Text(text).font(Theme.sora(15)).foregroundColor(Theme.inkDim).multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button(loc.t("newGame")) { vm.showResult = false; vm.newGame(mode: vm.mode, level: vm.botLevel) }.buttonStyle(GhostButtonStyle())
                Button(loc.t("backToMenu")) { vm.showResult = false; onBackToMenu() }.buttonStyle(GhostButtonStyle())
            }
        }
        .padding(32)
        .presentationDetents([.height(280)])
    }
}
