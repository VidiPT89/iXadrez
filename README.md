# ♚ Xadrez — Joga, Aprende, Domina o Tabuleiro (iOS)

> Uma app de xadrez nativa para iPhone e iPad, construída com Swift e SwiftUI — joga 1 vs 1, desafia um bot com 4 níveis de dificuldade, e aprende com um tutorial passo-a-passo.

A versão iOS nativa de [Xadrez para web](https://github.com/VidiPT89/Xadrez). Xadrez é uma app de jogo de tabuleiro completa construída com **Swift** e **SwiftUI** — sem bibliotecas de xadrez externas, sem dependências de terceiros. O motor de regras, a inteligência artificial e toda a interface são feitos de raiz. Joga uma partida local a dois, desafia o bot num dos quatro níveis de dificuldade, ou aprende a jogar do zero com lições interativas sobre movimentação, regras especiais, aberturas, táticas e finais.

## 📦 What's Inside

- ♟️ Motor de regras completo: todos os movimentos das peças, roque (ambos os lados), en passant, promoção, xeque, xeque-mate, afogamento, regra dos 50 lances, material insuficiente e repetição tripla
- 📜 Histórico de lances em notação algébrica simplificada, com desambiguação automática
- 🧑‍🤝‍🧑 Modo 1 vs 1 — dois jogadores alternam no mesmo dispositivo
- 🤖 Modo Contra o Bot com 4 níveis de dificuldade (Iniciante, Fácil, Médio, Difícil), motor minimax com poda alfa-beta, tabelas de posição por peça e pesquisa por tempo limitado no nível Difícil
- 🧠 O bot pesquisa numa thread de fundo dedicada — nunca bloqueia a interface, mesmo a pensar em profundidade
- 🎓 Modo Tutorial com 5 lições interativas: movimentação das peças, regras especiais, princípios de abertura, táticas básicas (garfos, cravos, espetos) e finais básicos
- ❓ Modo Ajuda com referência rápida de regras, modos de jogo e controlos
- 🇵🇹 🇬🇧 Alternância de idioma entre Português Europeu e Inglês, guardada entre sessões
- 🔊 Efeitos sonoros sintetizados em tempo real via `AVAudioEngine` para lances, capturas, xeque e fim de jogo
- 🎬 Splash de abertura animado com apresentação da app, que desaparece automaticamente
- 🖼️ Tabuleiro totalmente adaptável (iPhone e iPad, portrait e landscape), com destaque de lances legais, última jogada e xeque

## 🛠️ Tech Stack

![Swift](https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-0D96F6?style=flat&logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-16%2B-black?style=flat&logo=ios&logoColor=white)
![Xcode](https://img.shields.io/badge/Xcode-147EFB?style=flat&logo=xcode&logoColor=white)

## 🏗️ Project Structure

```
iXadrez/
├── project.yml               # XcodeGen project spec (source of truth for the .xcodeproj)
├── iXadrez.xcodeproj          # Generated Xcode project — open this in Xcode
└── iXadrez/
    ├── iXadrezApp.swift        # App entry point, screen router, header and footer
    ├── ChessEngine.swift        # Motor de regras puro (geração e validação de lances, notação)
    ├── ChessAI.swift              # Bot de IA (minimax + poda alfa-beta), corre em background
    ├── GameViewModel.swift         # Estado do jogo, liga o motor à interface
    ├── ChessBoardView.swift         # Renderização do tabuleiro, partilhada entre jogo e tutorial
    ├── GameView.swift                 # Ecrã de jogo: tabuleiro, painel, promoção, resultado
    ├── MainMenuView.swift              # Menu principal e seletor de dificuldade
    ├── TutorialView.swift               # 5 lições interativas
    ├── HelpView.swift                    # Referência de regras e controlos
    ├── SplashView.swift                   # Apresentação inicial
    ├── SoundEngine.swift                   # Sintetizador de efeitos sonoros em tempo real
    ├── Localization.swift                   # Strings PT/EN
    ├── Theme.swift                           # Cores e estilos partilhados
    └── Assets.xcassets                        # Ícone da app
```

## ⚙️ Game Mechanics

```
Cada lance:
  1. O jogador ativo toca numa peça sua — os lances legais dessa peça ficam destacados
  2. Toca numa casa destacada para jogar (um anel indica captura)
  3. Se o lance for uma promoção, uma folha pede a peça de destino (Dama, Torre, Bispo ou Cavalo)
  4. O motor atualiza o estado: roque, en passant e direitos de roque são geridos automaticamente
  5. Após o lance, verifica-se xeque, xeque-mate, afogamento e as três regras de empate
  6. No modo Contra o Bot, quando é a vez das Pretas, uma thread de fundo calcula o melhor
     lance para o nível escolhido e devolve-o à thread principal assim que termina
```

## 🤖 Níveis do Bot

```
Iniciante — profundidade 1, comete erros propositadamente com frequência
Fácil     — profundidade 2, pequena margem de aleatoriedade
Médio     — profundidade 3, quase sempre joga o melhor lance encontrado
Difícil   — profundidade 4+ com quiescence search e aprofundamento iterativo,
            sempre o melhor lance dentro do tempo disponível
```

## 🚀 How to Run

```bash
# 1. Clone the repository
git clone https://github.com/VidiPT89/iXadrez.git
cd iXadrez

# 2. (Optional) regenerate the Xcode project from project.yml
brew install xcodegen
xcodegen generate

# 3. Open in Xcode and run on a simulator or device
open iXadrez.xcodeproj
```

Requires Xcode 15+ and iOS 16+.

## 📝 Notes

- Todo o motor de xadrez e a IA foram escritos de raiz, sem bibliotecas externas
- O `.xcodeproj` é gerado a partir de `project.yml` com [XcodeGen](https://github.com/yonaskolb/XcodeGen) e está incluído no repositório para que o projeto abra diretamente sem passos extra
- As preferências de idioma e som são guardadas com `UserDefaults`, persistindo entre sessões

---

Developed by **David Arsénio Martins**
