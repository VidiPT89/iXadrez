import SwiftUI
import FirebaseCore

@main
struct iXadrezApp: App {
    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

private enum AppScreen {
    case menu, game, tutorial, help, multiplayerLobby, coachHome, coachReview
}

/// The game handed to the Coach: its moves, who the user played, and how to retry a position.
private struct CoachSource {
    let records: [MoveRecord]
    let playerColor: PieceColor?
    let retryMode: GameMode
    let level: BotDifficulty
}

struct ContentView: View {
    @ObservedObject var loc = Loc.shared
    @StateObject private var vm = GameViewModel()
    @StateObject private var mpVM = MultiplayerViewModel()
    @State private var screen: AppScreen = .menu
    @State private var coachSource: CoachSource? = nil
    @State private var coachReturn: AppScreen = .menu
    @State private var showSplash = true
    @State private var soundOn = SoundEngine.shared.isOn

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Group {
                    switch screen {
                    case .menu:
                        MainMenuView(
                            onStart1v1: { vm.newGame(mode: .oneVOne); screen = .game },
                            onStartBot: { level in vm.newGame(mode: .bot, level: level); screen = .game },
                            onOpenTutorial: { screen = .tutorial },
                            onOpenHelp: { screen = .help },
                            onOpenMultiplayer: { screen = .multiplayerLobby },
                            onOpenCoach: { screen = .coachHome }
                        )
                    case .game:
                        GameView(vm: vm, onBackToMenu: { screen = .menu }, onOpenCoach: openCoachForCurrentGame)
                    case .coachHome:
                        CoachHomeView(onOpenReview: openSavedReview, onBack: { screen = .menu })
                    case .coachReview:
                        if let source = coachSource {
                            CoachView(
                                records: source.records,
                                playerColor: source.playerColor,
                                onRetry: { prefix in
                                    vm.newGame(from: prefix, mode: source.retryMode, level: source.level)
                                    screen = .game
                                },
                                onBack: { screen = coachReturn }
                            )
                            .id(CoachStore.encode(source.records))
                        }
                    case .tutorial:
                        TutorialView(onBackToMenu: { screen = .menu })
                    case .help:
                        HelpView(onBackToMenu: { screen = .menu })
                    case .multiplayerLobby:
                        MultiplayerLobbyView(
                            mpVM: mpVM,
                            gameVM: vm,
                            onReady: { screen = .game },
                            onBack: { screen = .menu }
                        )
                    }
                }
                .frame(maxHeight: .infinity)
                footer
            }

            if showSplash {
                SplashView(onDismiss: { withAnimation { showSplash = false } })
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .foregroundColor(Theme.ink)
    }

    private func openCoachForCurrentGame() {
        let playerColor: PieceColor? = switch vm.mode {
        case .bot: GameViewModel.botColor.opponent
        case .multiplayer: vm.networkColor
        case .oneVOne: nil
        }
        coachSource = CoachSource(records: vm.game.history, playerColor: playerColor,
                                  retryMode: vm.mode == .bot ? .bot : .oneVOne, level: vm.botLevel)
        coachReturn = .menu
        screen = .coachReview
    }

    private func openSavedReview(_ review: SavedReview) {
        let playerColor = review.playerColor.flatMap(PieceColor.init(rawValue:))
        // Retrying as White means facing the bot again; any other side is replayed on one device.
        coachSource = CoachSource(records: CoachStore.decode(review.moves), playerColor: playerColor,
                                  retryMode: playerColor == .white ? .bot : .oneVOne, level: vm.botLevel)
        coachReturn = .coachHome
        screen = .coachReview
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Text("♚").font(Theme.sora(22)).foregroundColor(Theme.gold)
                Text("Xadrez").font(Theme.soraExtraBold(20))
            }
            Spacer()
            Button {
                soundOn = SoundEngine.shared.toggleSound()
                if soundOn { SoundEngine.shared.playClick() }
            } label: {
                Text(soundOn ? "🔊" : "🔇")
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Capsule().fill(Theme.panel).overlay(Capsule().stroke(Theme.panelBorder, lineWidth: 1)))
            }
            Button {
                loc.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(loc.language == .pt ? "🇵🇹" : "🇬🇧")
                    Text(loc.language.rawValue.uppercased()).font(Theme.sora(13, weight: .bold))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(Theme.panel).overlay(Capsule().stroke(Theme.panelBorder, lineWidth: 1)))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Theme.bg.opacity(0.9))
    }

    private var footer: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(loc.t("footerBy")).foregroundColor(Theme.inkDim)
                Text("David Arsénio Martins").fontWeight(.bold).foregroundColor(Theme.goldSoft)
            }
            .font(Theme.sora(12))
            HStack(spacing: 8) {
                Link("ividi.dev", destination: URL(string: "https://ividi.dev/")!)
                Text("·").foregroundColor(Theme.inkDim)
                Link("GitHub", destination: URL(string: "https://github.com/VidiPT89/iXadrez")!)
            }
            .font(Theme.sora(12))
            .foregroundColor(Theme.inkDim)
        }
        .padding(.vertical, 10)
    }
}
