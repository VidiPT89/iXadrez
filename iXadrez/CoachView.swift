import SwiftUI

/// Post-game review: grades every move, explains the mistakes and lets the player retry them.
struct CoachView: View {
    @ObservedObject var loc = Loc.shared
    let records: [MoveRecord]
    /// The color the user played; nil when both sides were played on this device.
    let playerColor: PieceColor?
    var onRetry: (([MoveRecord]) -> Void)? = nil
    var onBack: () -> Void

    @State private var report: CoachReport? = nil
    @State private var progress: Double = 0
    /// Selected ply; -1 is the starting position.
    @State private var ply: Int = -1

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(loc.t("coachTitle")).font(Theme.soraExtraBold(28)).foregroundColor(Theme.goldSoft)
                    Text(loc.t("coachOnDevice")).font(Theme.sora(12)).foregroundColor(Theme.inkDim)
                }
                if let report {
                    summaryCard(report)
                    board(report)
                    navigation(report)
                    explanationCard(report)
                    keyMomentsCard(report)
                    allMovesCard(report)
                } else {
                    VStack(spacing: 12) {
                        ProgressView(value: progress).tint(Theme.gold)
                        Text(loc.t("coachAnalysing")).font(Theme.sora(14)).foregroundColor(Theme.inkDim)
                    }
                    .padding(24)
                    .accessibilityIdentifier("coach-analysing")
                }
                Button(loc.t("backToMenu")) { onBack() }.buttonStyle(GhostButtonStyle())
            }
            .padding(20)
        }
        .onAppear(perform: analyse)
    }

    private func analyse() {
        guard report == nil else { return }
        let records = records, playerColor = playerColor
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ChessCoach.review(records) { value in
                DispatchQueue.main.async { progress = value }
            }
            DispatchQueue.main.async {
                CoachStore.shared.save(report: result, records: records, playerColor: playerColor)
                report = result
                ply = result.moves.firstIndex { isMine($0) && $0.quality >= .mistake } ?? -1
            }
        }
    }

    private func isMine(_ move: CoachMoveReview) -> Bool {
        playerColor == nil || move.record.color == playerColor
    }

    // MARK: Cards

    private func summaryCard(_ report: CoachReport) -> some View {
        HStack(spacing: 12) {
            accuracyColumn(.white, report.accuracyWhite, report)
            Rectangle().fill(Theme.panelBorder).frame(width: 1)
            accuracyColumn(.black, report.accuracyBlack, report)
        }
        .padding(16)
        .background(panel)
    }

    private func accuracyColumn(_ color: PieceColor, _ accuracy: Int, _ report: CoachReport) -> some View {
        VStack(spacing: 6) {
            let side = loc.t(color == .white ? "whitePlayer" : "blackPlayer")
            Text(playerColor == color ? "\(side) · \(loc.t("coachYou"))" : side)
                .font(Theme.sora(13, weight: .semibold)).foregroundColor(Theme.ink)
            Text("\(accuracy)%").font(Theme.soraExtraBold(30)).foregroundColor(Theme.goldSoft)
            Text(loc.t("coachAccuracy")).font(Theme.sora(11)).foregroundColor(Theme.inkDim).textCase(.uppercase)
            HStack(spacing: 6) {
                ForEach([MoveQuality.inaccuracy, .mistake, .blunder], id: \.self) { q in
                    Text("\(q.symbol) \(report.count(q, for: color))")
                        .font(Theme.sora(12, weight: .bold))
                        .foregroundColor(Self.color(q))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func board(_ report: CoachReport) -> some View {
        let move = ply >= 0 ? report.moves[ply] : nil
        // With a suggestion, show the position before the move: the played move in gold, the better one in green.
        let showBefore = move?.bestFrom != nil
        let boardIndex = move == nil ? 0 : (showBefore ? ply : ply + 1)
        let hint = move.flatMap { m in m.bestFrom.flatMap { from in m.bestTo.map { (from, $0) } } }
        return VStack(spacing: 6) {
            ChessBoardView(
                pieces: PieceInstance.fresh(from: report.boards[boardIndex]),
                lastMove: move.map { ($0.record.from, $0.record.to) },
                hint: hint,
                flipped: playerColor == .black
            )
            .frame(width: boardSize, height: boardSize)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("coach-board")
            if hint != nil {
                Text(loc.t("coachSuggested")).font(Theme.sora(12)).foregroundColor(Theme.hint)
            }
        }
    }

    private func navigation(_ report: CoachReport) -> some View {
        HStack(spacing: 10) {
            Button("◀ " + loc.t("prevLesson")) { ply = max(-1, ply - 1) }
                .buttonStyle(GhostButtonStyle()).disabled(ply < 0)
            Button(loc.t("nextLesson") + " ▶") { ply = min(report.moves.count - 1, ply + 1) }
                .buttonStyle(GhostButtonStyle()).disabled(ply >= report.moves.count - 1)
                .accessibilityIdentifier("coach-next")
        }
    }

    private func explanationCard(_ report: CoachReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if ply >= 0 {
                let move = report.moves[ply]
                HStack {
                    Text("\(moveNumber(ply)) \(sanText(move.record.san, loc.language))").font(Theme.sora(17, weight: .bold)).foregroundColor(Theme.ink)
                    Spacer()
                    Text("\(move.quality.symbol) \(loc.t("q_" + move.quality.rawValue))")
                        .font(Theme.sora(13, weight: .bold)).foregroundColor(Self.color(move.quality))
                }
                Text(move.text(loc.language)).font(Theme.sora(14)).foregroundColor(Theme.ink)
                Text("\(loc.t("coachEval")): \(String(format: "%+.1f", Double(move.evalAfter) / 100))")
                    .font(Theme.sora(12)).foregroundColor(Theme.inkDim)
                if let onRetry, isMine(move), move.quality >= .inaccuracy {
                    Button(loc.t("coachRetry")) { onRetry(Array(records.prefix(ply))) }
                        .buttonStyle(GhostButtonStyle())
                        .padding(.top, 4)
                }
            } else {
                Text(loc.t("coachStartTitle")).font(Theme.sora(17, weight: .bold)).foregroundColor(Theme.ink)
                Text(loc.t("coachStartText")).font(Theme.sora(14)).foregroundColor(Theme.inkDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(panel)
    }

    private func keyMomentsCard(_ report: CoachReport) -> some View {
        let key = report.moves.filter { isMine($0) && $0.quality >= .inaccuracy }
        return VStack(alignment: .leading, spacing: 8) {
            sectionTitle(loc.t("coachKeyMoments"))
            if key.isEmpty {
                Text(loc.t("coachNoKeyMoments")).font(Theme.sora(14)).foregroundColor(Theme.inkDim)
            }
            ForEach(key) { move in
                Button { ply = move.id } label: {
                    HStack(spacing: 10) {
                        Text(move.quality.symbol).font(Theme.sora(14, weight: .bold)).foregroundColor(Self.color(move.quality)).frame(width: 28)
                        Text("\(moveNumber(move.id)) \(sanText(move.record.san, loc.language))").font(Theme.sora(14, weight: .semibold)).foregroundColor(Theme.ink)
                        if let theme = move.theme {
                            Text(loc.t("theme_" + theme.rawValue)).font(Theme.sora(12)).foregroundColor(Theme.inkDim)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6).padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(ply == move.id ? Theme.gold : Theme.panelBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(panel)
    }

    private func allMovesCard(_ report: CoachReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(loc.t("coachAllMoves"))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(report.moves) { move in
                    Button { ply = move.id } label: {
                        HStack(spacing: 3) {
                            Text("\(moveNumber(move.id))\(sanText(move.record.san, loc.language))").font(.system(.footnote, design: .monospaced)).foregroundColor(Theme.ink)
                                .lineLimit(1).minimumScaleFactor(0.7)
                            if move.quality >= .inaccuracy {
                                Text(move.quality.symbol).font(.system(.caption2, design: .monospaced).bold()).foregroundColor(Self.color(move.quality))
                            }
                        }
                        .padding(.vertical, 4).padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(ply == move.id ? Theme.gold.opacity(0.18) : Theme.bgSoft))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(panel)
    }

    // MARK: Helpers

    private func moveNumber(_ ply: Int) -> String {
        "\(ply / 2 + 1)\(ply % 2 == 0 ? "." : "…")"
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(Theme.sora(12, weight: .bold)).foregroundColor(Theme.inkDim).textCase(.uppercase)
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: 16).fill(Theme.panel).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.panelBorder, lineWidth: 1))
    }

    private var boardSize: CGFloat {
        let screen = UIScreen.main.bounds
        return min(screen.width - 40, screen.height * 0.5, 640)
    }

    static func color(_ quality: MoveQuality) -> Color {
        switch quality {
        case .best, .good: return Theme.hint
        case .inaccuracy: return Theme.goldSoft
        case .mistake: return Color(red: 0.902, green: 0.553, blue: 0.247)
        case .blunder: return Theme.danger
        }
    }
}
