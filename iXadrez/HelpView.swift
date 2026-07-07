import SwiftUI

private struct HelpBlock {
    let titlePt: String, titleEn: String
    let bodyPt: String, bodyEn: String
    func title(_ lang: AppLanguage) -> String { lang == .pt ? titlePt : titleEn }
    func body(_ lang: AppLanguage) -> String { lang == .pt ? bodyPt : bodyEn }
}

private let helpBlocks: [HelpBlock] = [
    HelpBlock(
        titlePt: "Objetivo", titleEn: "Objective",
        bodyPt: "Dar xeque-mate ao rei adversário — colocá-lo sob ataque sem qualquer forma de escapar.",
        bodyEn: "Checkmate the opponent's king — put it under attack with no way to escape."
    ),
    HelpBlock(
        titlePt: "Como jogar", titleEn: "How to play",
        bodyPt: "Toca numa peça tua para a selecionar — os lances possíveis ficam marcados com um ponto (ou um anel, se for uma captura). Toca numa das casas marcadas para jogar. Toca noutra peça tua para trocar a seleção.",
        bodyEn: "Tap one of your pieces to select it — legal moves are marked with a dot (or a ring, for a capture). Tap a marked square to play the move. Tap another of your pieces to change the selection."
    ),
    HelpBlock(
        titlePt: "Modos de jogo", titleEn: "Game modes",
        bodyPt: "• 1 vs 1 — dois jogadores alternam turnos no mesmo dispositivo.\n• Contra o Bot — escolhe entre 4 níveis de dificuldade (Iniciante a Difícil); jogas sempre com as Brancas e o bot joga com as Pretas.\n• Tutorial — lições passo-a-passo sobre movimentação, regras especiais, aberturas, táticas e finais.",
        bodyEn: "• 1 vs 1 — two players take turns on the same device.\n• Vs Bot — choose between 4 difficulty levels (Beginner to Hard); you always play White and the bot plays Black.\n• Tutorial — step-by-step lessons on piece movement, special rules, openings, tactics and endgames."
    ),
    HelpBlock(
        titlePt: "Controlos", titleEn: "Controls",
        bodyPt: "Inverter — roda o tabuleiro 180°.\nNovo Jogo — reinicia a partida atual.\nMenu — volta ao menu principal.\n🔊 — liga/desliga o som.\n🇵🇹/🇬🇧 — muda o idioma entre Português e Inglês.",
        bodyEn: "Flip — rotates the board 180°.\nNew Game — restarts the current match.\nMenu — returns to the main menu.\n🔊 — toggles sound on/off.\n🇵🇹/🇬🇧 — switches the language between Portuguese and English."
    ),
]

struct HelpView: View {
    @ObservedObject var loc = Loc.shared
    var onBackToMenu: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(loc.t("helpTitle"))
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(Theme.goldSoft)

                ForEach(0..<helpBlocks.count, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(helpBlocks[i].title(loc.language))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.goldSoft)
                        Text(helpBlocks[i].body(loc.language))
                            .font(.system(size: 14))
                            .foregroundColor(Theme.inkDim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panel).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.panelBorder, lineWidth: 1)))
                }

                Button(loc.t("backToMenu")) { onBackToMenu() }.buttonStyle(GhostButtonStyle())
            }
            .padding(20)
        }
    }
}
