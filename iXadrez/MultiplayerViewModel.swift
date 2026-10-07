import Foundation
import Combine

/// Thin wrapper that bridges MultiplayerService (Firestore) and GameViewModel (local board
/// state), so GameViewModel itself never has to know about Firebase types.
@MainActor
final class MultiplayerViewModel: ObservableObject {
    let service = MultiplayerService.shared
    @Published var errorMessage: String? = nil
    @Published var waitingForOpponent = false
    /// What the player typed in the lobby (may be blank — the default name is used then).
    @Published var playerName: String = UserDefaults.standard.string(forKey: MultiplayerViewModel.nameKey) ?? ""

    private static let nameKey = "playerName"

    /// Called before any room action: remembers the typed name and hands it to the service.
    private func commitPlayerName() {
        playerName = MultiplayerService.cleanName(playerName)
        UserDefaults.standard.set(playerName, forKey: Self.nameKey)
        service.myName = playerName.isEmpty ? Loc.shared.t("mpDefaultName") : playerName
    }

    private func begin(gameVM: GameViewModel) {
        service.onRemoteMove = { [weak gameVM] from, to, promotion in
            gameVM?.applyRemoteMove(from: from, to: to, promotion: promotion)
        }
        service.onGameFinished = { [weak gameVM] result in
            // Checkmate/draw endings are detected by the local engine, which already shows them.
            guard result.hasPrefix("resign-") else { return }
            gameVM?.multiplayerResult = result
        }
        gameVM.newGame(mode: .multiplayer, networkColor: nil)
        gameVM.onLocalMove = { [weak self, weak gameVM] record in
            guard let self else { return }
            self.service.sendMove(from: record.from, to: record.to, promotion: record.promotion)
            // Whoever played the final move records the ending, which also frees a Quick Play slot.
            if let game = gameVM?.game, let ending = Self.endingCode(game) {
                self.service.finishGame(result: ending)
            }
        }
    }

    func createRoom(gameVM: GameViewModel, onReady: @escaping () -> Void) {
        commitPlayerName()
        begin(gameVM: gameVM)
        errorMessage = nil
        waitingForOpponent = false
        service.onOpponentJoined = { [weak self] in
            self?.waitingForOpponent = false
            onReady()
        }
        Task {
            do {
                _ = try await service.createRoom()
                seat(gameVM)
                waitingForOpponent = true
            } catch {
                errorMessage = Self.message(for: error)
            }
        }
    }

    func joinRoom(_ code: String, gameVM: GameViewModel, onReady: @escaping () -> Void) {
        commitPlayerName()
        begin(gameVM: gameVM)
        errorMessage = nil
        Task {
            do {
                _ = try await service.joinRoom(code)
                seat(gameVM)
                onReady()
            } catch {
                errorMessage = Self.message(for: error)
            }
        }
    }

    func quickPlay(gameVM: GameViewModel, onReady: @escaping () -> Void) {
        commitPlayerName()
        begin(gameVM: gameVM)
        errorMessage = nil
        waitingForOpponent = false
        service.onOpponentJoined = { [weak self] in
            self?.waitingForOpponent = false
            onReady()
        }
        Task {
            do {
                let result = try await service.quickPlay()
                seat(gameVM)
                if result.isHost {
                    waitingForOpponent = true
                } else {
                    onReady()
                }
            } catch {
                errorMessage = Self.message(for: error)
            }
        }
    }

    /// Records my color and puts my pieces at the bottom of the board — the guest plays Black.
    private func seat(_ gameVM: GameViewModel) {
        gameVM.networkColor = service.myColor
        gameVM.flipped = service.myColor == .black
    }

    /// "checkmate-w", "stalemate", "draw-50"… — the same codes the web version writes.
    private static func endingCode(_ game: ChessGame) -> String? {
        switch game.result {
        case .checkmate: return "checkmate-" + (game.winner?.rawValue ?? "")
        case .stalemate: return "stalemate"
        case .draw50: return "draw-50"
        case .drawRepetition: return "draw-repetition"
        case .drawMaterial: return "draw-material"
        case .none: return nil
        }
    }

    func leave() {
        service.leaveRoom()
        waitingForOpponent = false
    }

    static func message(for error: Error) -> String {
        switch error as? MultiplayerError {
        case .roomNotFound: return Loc.shared.t("mpErrorNotFound")
        case .roomFull: return Loc.shared.t("mpErrorFull")
        case .roomFinished: return Loc.shared.t("mpErrorFinished")
        case .lobbyFull: return Loc.shared.t("mpErrorLobbyFull")
        case .notConfigured: return Loc.shared.t("mpNotConfigured")
        default: return Loc.shared.t("mpErrorGeneric")
        }
    }
}
