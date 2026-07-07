import Foundation
import Combine

enum AppLanguage: String {
    case pt, en
}

private let strings: [AppLanguage: [String: String]] = [
    .pt: [
        "menuTitle": "Xadrez",
        "menuSubtitle": "Escolhe um modo para começar",
        "mode1v1": "1 vs 1",
        "mode1v1Desc": "Dois jogadores, mesmo ecrã",
        "modeBot": "Contra o Bot",
        "modeBotDesc": "Escolhe o nível da IA",
        "modeTutorial": "Tutorial",
        "modeTutorialDesc": "Aprende a jogar por níveis",
        "modeHelp": "Ajuda",
        "modeHelpDesc": "Regras e controlos",
        "chooseDifficulty": "Escolhe o nível do bot",
        "levelBeginner": "Iniciante",
        "levelEasy": "Fácil",
        "levelMedium": "Médio",
        "levelHard": "Difícil",
        "cancelBtn": "Cancelar",
        "blackPlayer": "Pretas",
        "whitePlayer": "Brancas",
        "moveHistory": "Histórico de Lances",
        "undoMove": "↩️ Voltar Atrás",
        "flipBoard": "Inverter",
        "newGame": "Novo Jogo",
        "backToMenu": "Menu",
        "prevLesson": "Anterior",
        "nextLesson": "Seguinte",
        "helpTitle": "Ajuda",
        "footerBy": "Desenvolvido por",
        "introTitle": "Xadrez",
        "introText": "Joga 1 vs 1, desafia o bot, aprende as regras e as estratégias — tudo num só tabuleiro.",
        "introSkip": "Saltar",
        "turnWhite": "Vez das Brancas",
        "turnBlack": "Vez das Pretas",
        "thinking": "O bot está a pensar…",
        "inCheck": "Xeque!",
        "resultCheckmateTitle": "Xeque-mate!",
        "resultCheckmateWhite": "As Brancas vencem.",
        "resultCheckmateBlack": "As Pretas vencem.",
        "resultStalemateTitle": "Tabuada por Afogamento",
        "resultStalemateText": "Nenhum jogador tem lances legais. O jogo termina empatado.",
        "resultDraw50Title": "Empate",
        "resultDraw50Text": "50 lances sem capturas nem movimento de peão.",
        "resultDrawRepTitle": "Empate",
        "resultDrawRepText": "A mesma posição repetiu-se três vezes.",
        "resultDrawMatTitle": "Empate",
        "resultDrawMatText": "Nenhum dos lados tem material suficiente para dar mate.",
        "promoTitle": "Promover peão a:",
        "lessonHintClick": "Toca numa peça para veres os seus movimentos.",
    ],
    .en: [
        "menuTitle": "Chess",
        "menuSubtitle": "Choose a mode to begin",
        "mode1v1": "1 vs 1",
        "mode1v1Desc": "Two players, same screen",
        "modeBot": "Vs Bot",
        "modeBotDesc": "Choose the AI level",
        "modeTutorial": "Tutorial",
        "modeTutorialDesc": "Learn to play, level by level",
        "modeHelp": "Help",
        "modeHelpDesc": "Rules and controls",
        "chooseDifficulty": "Choose the bot's level",
        "levelBeginner": "Beginner",
        "levelEasy": "Easy",
        "levelMedium": "Medium",
        "levelHard": "Hard",
        "cancelBtn": "Cancel",
        "blackPlayer": "Black",
        "whitePlayer": "White",
        "moveHistory": "Move History",
        "undoMove": "↩️ Undo",
        "flipBoard": "Flip",
        "newGame": "New Game",
        "backToMenu": "Menu",
        "prevLesson": "Previous",
        "nextLesson": "Next",
        "helpTitle": "Help",
        "footerBy": "Developed by",
        "introTitle": "Chess",
        "introText": "Play 1 vs 1, challenge the bot, learn the rules and strategy — all on one board.",
        "introSkip": "Skip",
        "turnWhite": "White to move",
        "turnBlack": "Black to move",
        "thinking": "The bot is thinking…",
        "inCheck": "Check!",
        "resultCheckmateTitle": "Checkmate!",
        "resultCheckmateWhite": "White wins.",
        "resultCheckmateBlack": "Black wins.",
        "resultStalemateTitle": "Stalemate",
        "resultStalemateText": "Neither player has a legal move. The game is a draw.",
        "resultDraw50Title": "Draw",
        "resultDraw50Text": "50 moves without a capture or pawn move.",
        "resultDrawRepTitle": "Draw",
        "resultDrawRepText": "The same position occurred three times.",
        "resultDrawMatTitle": "Draw",
        "resultDrawMatText": "Neither side has enough material to checkmate.",
        "promoTitle": "Promote pawn to:",
        "lessonHintClick": "Tap a piece to see how it moves.",
    ],
]

final class Loc: ObservableObject {
    static let shared = Loc()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "xadrez-lang") }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "xadrez-lang")
        self.language = AppLanguage(rawValue: saved ?? "pt") ?? .pt
    }

    func toggle() {
        language = language == .pt ? .en : .pt
    }

    func t(_ key: String) -> String {
        strings[language]?[key] ?? strings[.pt]?[key] ?? key
    }
}
