import SwiftUI

struct MainMenuView: View {
    @ObservedObject var loc = Loc.shared
    @State private var showDifficulty = false

    var onStart1v1: () -> Void
    var onStartBot: (BotDifficulty) -> Void
    var onOpenTutorial: () -> Void
    var onOpenHelp: () -> Void
    var onOpenMultiplayer: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 8) {
                        Text(loc.t("menuTitle"))
                            .font(Theme.soraExtraBold(40))
                            .foregroundColor(Theme.goldSoft)
                        Text(loc.t("menuSubtitle"))
                            .font(Theme.sora(16))
                            .foregroundColor(Theme.inkDim)
                    }
                    .padding(.top, 12)

                    LazyVGrid(columns: columns, spacing: 16) {
                        modeCard(icon: "🧑‍🤝‍🧑", title: loc.t("mode1v1"), desc: loc.t("mode1v1Desc")) {
                            showDifficulty = false
                            onStart1v1()
                        }
                        modeCard(icon: "🤖", title: loc.t("modeBot"), desc: loc.t("modeBotDesc")) {
                            withAnimation { showDifficulty = true }
                        }
                        modeCard(icon: "🎓", title: loc.t("modeTutorial"), desc: loc.t("modeTutorialDesc")) {
                            onOpenTutorial()
                        }
                        modeCard(icon: "❓", title: loc.t("modeHelp"), desc: loc.t("modeHelpDesc")) {
                            onOpenHelp()
                        }
                        modeCard(icon: "🌐", title: loc.t("modeMultiplayer"), desc: loc.t("modeMultiplayerDesc")) {
                            showDifficulty = false
                            onOpenMultiplayer()
                        }
                    }
                }
                .padding(20)
            }

            if showDifficulty {
                Color.black.opacity(0.72)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { showDifficulty = false } }
                difficultyPanel
            }
        }
    }

    private func modeCard(icon: String, title: String, desc: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(icon).font(Theme.sora(34))
                Text(title).font(Theme.sora(16, weight: .bold)).foregroundColor(Theme.ink)
                Text(desc).font(Theme.sora(12)).foregroundColor(Theme.inkDim).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panel).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.panelBorder, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private var difficultyPanel: some View {
        VStack(spacing: 14) {
            Text(loc.t("chooseDifficulty")).font(Theme.sora(15, weight: .bold)).foregroundColor(Theme.ink)
            LazyVGrid(columns: columns, spacing: 12) {
                difficultyButton(.beginner, stars: "★☆☆☆", label: loc.t("levelBeginner"))
                difficultyButton(.easy, stars: "★★☆☆", label: loc.t("levelEasy"))
                difficultyButton(.medium, stars: "★★★☆", label: loc.t("levelMedium"))
                difficultyButton(.hard, stars: "★★★★", label: loc.t("levelHard"))
            }
            Button(loc.t("cancelBtn")) { withAnimation { showDifficulty = false } }.buttonStyle(GhostButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: 480)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panel).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.panelBorder, lineWidth: 1)))
    }

    private func difficultyButton(_ level: BotDifficulty, stars: String, label: String) -> some View {
        Button {
            onStartBot(level)
        } label: {
            VStack(spacing: 4) {
                Text(stars).foregroundColor(Theme.goldSoft).tracking(2)
                Text(label).font(Theme.sora(14, weight: .semibold)).foregroundColor(Theme.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bgSoft).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.panelBorder, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }
}
