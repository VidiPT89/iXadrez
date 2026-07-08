import Foundation
import Combine

/// Thin wrapper that bridges MultiplayerService (Firestore) and GameViewModel (local board
/// state), so GameViewModel itself never has to know about Firebase types.
@MainActor
final class MultiplayerViewModel: ObservableObject {
    let service = MultiplayerService.shared
    @Published var errorMessage: String? = nil
    @Published var waitingForOpponent = false

    private func begin(gameVM: GameViewModel) {
        service.onRemoteMove = { [weak gameVM] from, to, promotion in
            gameVM?.applyRemoteMove(from: from, to: to, promotion: promotion)
        }
        service.onGameFinished = { [weak gameVM] result in
            gameVM?.multiplayerResult = result
        }
        gameVM.newGame(mode: .multiplayer, networkColor: nil)
        gameVM.onLocalMove = { [weak self] record in
            self?.service.sendMove(from: record.from, to: record.to, promotion: record.promotion)
        }
    }

    func createRoom(gameVM: GameViewModel, onReady: @escaping () -> Void) {
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
                gameVM.networkColor = service.myColor
                waitingForOpponent = true
            } catch {
                errorMessage = Self.message(for: error)
            }
        }
    }

    func joinRoom(_ code: String, gameVM: GameViewModel, onReady: @escaping () -> Void) {
        begin(gameVM: gameVM)
        errorMessage = nil
        Task {
            do {
                _ = try await service.joinRoom(code)
                gameVM.networkColor = service.myColor
                onReady()
            } catch {
                errorMessage = Self.message(for: error)
            }
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
        case .notConfigured: return Loc.shared.t("mpNotConfigured")
        default: return Loc.shared.t("mpErrorGeneric")
        }
    }
}
