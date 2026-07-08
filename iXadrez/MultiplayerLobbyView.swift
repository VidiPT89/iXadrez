import SwiftUI

struct MultiplayerLobbyView: View {
    @ObservedObject var loc = Loc.shared
    @ObservedObject var mpVM: MultiplayerViewModel
    var gameVM: GameViewModel
    var onReady: () -> Void
    var onBack: () -> Void

    private enum Step { case choice, join }
    @State private var step: Step = .choice
    @State private var joinCode: String = ""

    var body: some View {
        VStack(spacing: 18) {
            Text(loc.t("mpTitle")).font(Theme.sora(20, weight: .bold)).foregroundColor(Theme.ink)

            if mpVM.waitingForOpponent {
                waitingView
            } else if step == .join {
                joinView
            } else {
                choiceView
            }

            if let error = mpVM.errorMessage {
                Text(error).font(Theme.sora(13)).foregroundColor(Theme.danger).multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: 480)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panel).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.panelBorder, lineWidth: 1)))
        .padding(20)
    }

    private var choiceView: some View {
        VStack(spacing: 14) {
            if !MultiplayerService.configured {
                Text(loc.t("mpNotConfigured")).font(Theme.sora(13)).foregroundColor(Theme.danger).multilineTextAlignment(.center)
            }
            HStack(spacing: 10) {
                Button(loc.t("mpCreateRoom")) {
                    mpVM.createRoom(gameVM: gameVM, onReady: onReady)
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(!MultiplayerService.configured)

                Button(loc.t("mpJoinRoom")) {
                    mpVM.errorMessage = nil
                    joinCode = ""
                    step = .join
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(!MultiplayerService.configured)
            }
            Button(loc.t("cancelBtn")) { onBack() }.buttonStyle(GhostButtonStyle())
        }
    }

    private var joinView: some View {
        VStack(spacing: 14) {
            Text(loc.t("mpEnterCode")).font(Theme.sora(15, weight: .bold)).foregroundColor(Theme.ink)
            TextField("ABC123", text: $joinCode)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)
                .multilineTextAlignment(.center)
                .font(.system(.title3, design: .monospaced))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bgSoft).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.panelBorder, lineWidth: 1)))
                .onChange(of: joinCode) { joinCode = String($0.uppercased().prefix(6)) }
            HStack(spacing: 10) {
                Button(loc.t("mpJoin")) {
                    mpVM.joinRoom(joinCode, gameVM: gameVM, onReady: onReady)
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(joinCode.count != 6)
                Button(loc.t("cancelBtn")) { step = .choice }.buttonStyle(GhostButtonStyle())
            }
        }
    }

    private var waitingView: some View {
        VStack(spacing: 14) {
            Text(loc.t("mpWaitingTitle")).font(Theme.sora(15, weight: .bold)).foregroundColor(Theme.ink)
            if let code = mpVM.service.roomCode {
                Text(code)
                    .font(.system(.largeTitle, design: .monospaced))
                    .tracking(6)
                    .foregroundColor(Theme.goldSoft)
                if let url = URL(string: "https://vidipt89.github.io/Xadrez/?room=\(code)") {
                    ShareLink(item: url, subject: Text("Xadrez"), message: Text(loc.t("mpShareText"))) {
                        Label(loc.t("mpShareLink"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }
            Button(loc.t("cancelBtn")) {
                mpVM.leave()
                step = .choice
            }.buttonStyle(GhostButtonStyle())
        }
    }
}
