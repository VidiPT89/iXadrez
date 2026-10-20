import SwiftUI

/// The Coach's home: accuracy over recent games, the patterns that cost the most, and past reviews.
struct CoachHomeView: View {
    @ObservedObject var loc = Loc.shared
    @ObservedObject var store = CoachStore.shared
    var onOpenReview: (SavedReview) -> Void
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(loc.t("coachProgressTitle")).font(Theme.soraExtraBold(28)).foregroundColor(Theme.goldSoft)
                    Text(loc.t("coachOnDevice")).font(Theme.sora(12)).foregroundColor(Theme.inkDim)
                }

                if store.reviews.isEmpty {
                    Text(loc.t("coachNoGames"))
                        .font(Theme.sora(14)).foregroundColor(Theme.inkDim).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(panel)
                        .accessibilityIdentifier("coach-empty")
                } else {
                    accuracyCard
                    if !store.topThemes.isEmpty { patternsCard }
                    pastGamesCard
                }

                Button(loc.t("backToMenu")) { onBack() }.buttonStyle(GhostButtonStyle())
            }
            .padding(20)
        }
    }

    private var accuracyCard: some View {
        VStack(spacing: 10) {
            Text(loc.t("coachRecentAccuracy")).font(Theme.sora(12, weight: .bold)).foregroundColor(Theme.inkDim).textCase(.uppercase)
            Text("\(store.recentAccuracy ?? 0)%").font(Theme.soraExtraBold(40)).foregroundColor(Theme.goldSoft)
            // Oldest on the left, so the bars read as a trend.
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(store.reviews.prefix(10).reversed())) { review in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.gold.opacity(0.35 + 0.65 * Double(review.accuracy) / 100))
                        .frame(width: 16, height: max(6, CGFloat(review.accuracy) * 0.7))
                }
            }
            .frame(height: 72, alignment: .bottom)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(panel)
    }

    private var patternsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(loc.t("coachYourPatterns"))
            ForEach(store.topThemes.prefix(3), id: \.theme) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(loc.t("theme_" + item.theme.rawValue)).font(Theme.sora(15, weight: .bold)).foregroundColor(Theme.ink)
                        Spacer()
                        Text("×\(item.count)").font(Theme.sora(14, weight: .bold)).foregroundColor(Theme.danger)
                    }
                    Text(loc.t("tip_" + item.theme.rawValue)).font(Theme.sora(13)).foregroundColor(Theme.inkDim)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(panel)
    }

    private var pastGamesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(loc.t("coachPastGames"))
            ForEach(store.reviews) { review in
                Button { onOpenReview(review) } label: {
                    HStack(spacing: 12) {
                        Text("\(review.accuracy)%").font(Theme.sora(18, weight: .bold)).foregroundColor(Theme.goldSoft).frame(width: 60, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(review.date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute()
                                .locale(Locale(identifier: loc.language == .pt ? "pt_PT" : "en_GB")))).font(Theme.sora(13, weight: .semibold)).foregroundColor(Theme.ink)
                            Text(subtitle(review)).font(Theme.sora(12)).foregroundColor(Theme.inkDim)
                        }
                        Spacer()
                        Text("›").font(Theme.sora(20)).foregroundColor(Theme.inkDim)
                    }
                    .padding(.vertical, 8).padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Theme.panelBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) { store.delete(review) } label: { Text(loc.t("coachDelete")) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(panel)
    }

    private func subtitle(_ review: SavedReview) -> String {
        let side: String
        switch review.playerColor {
        case "w": side = loc.t("coachPlayWhite")
        case "b": side = loc.t("coachPlayBlack")
        default: side = loc.t("coachBothSides")
        }
        let moves = loc.t("coachMovesN").replacingOccurrences(of: "{n}", with: "\(review.moves.split(separator: ",").count)")
        let mistakes = loc.t("coachMistakesN").replacingOccurrences(of: "{n}", with: "\(review.mistakes)")
        return "\(side) · \(moves) · \(mistakes)"
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(Theme.sora(12, weight: .bold)).foregroundColor(Theme.inkDim).textCase(.uppercase)
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: 16).fill(Theme.panel).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.panelBorder, lineWidth: 1))
    }
}
