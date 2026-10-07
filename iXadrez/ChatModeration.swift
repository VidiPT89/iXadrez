import Foundation

/// Keeps the online chat within App Store rule 1.2 (user-generated content): offensive words are
/// masked before display, the opponent can be muted, and abuse can be reported by email.
enum ChatModeration {
    static let reportEmail = "ividi.dev@gmail.com"

    /// Lower-case, accent-free stems: a word is masked when its folded form starts with one, which
    /// also catches plurals and inflections ("idiotas", "fucking").
    private static let blockedStems: [String] = [
        // Português (de Portugal: "bicha" é fila e "puto" é miúdo, por isso não entram)
        "caralh", "foda", "fodas", "fodid", "merda", "paneleir", "panasc", "cabrao", "otario",
        "idiota", "imbecil", "estupid", "atrasad", "mongoloid", "retardad", "filhodaputa",
        // English
        "fuck", "shit", "bitch", "cunt", "pussy", "asshole", "bastard", "slut", "whore",
        "retard", "faggot", "nigg", "idiot", "moron", "stupid",
    ]

    /// Short words that would hit innocent ones as stems ("Dickens", "cockpit"), so exact only.
    private static let blockedWords: Set<String> = [
        "puta", "putas", "cona", "pila", "corno", "cornos", "fode", "fdp", "crl", "pqp", "vsf", "vtnc",
        "dick", "cock", "fag", "kys", "rape",
    ]

    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber }
    }

    /// Replaces each offending word with "•••", leaving the rest of the message intact.
    static func mask(_ text: String) -> String {
        text.split(separator: " ", omittingEmptySubsequences: false).map { word -> String in
            let folded = fold(String(word))
            guard !folded.isEmpty,
                  blockedWords.contains(folded) || blockedStems.contains(where: { folded.hasPrefix($0) }) else { return String(word) }
            return "•••"
        }.joined(separator: " ")
    }

    /// A pre-filled email to the developer with the evidence needed to act on a report.
    static func reportURL(roomCode: String?, opponentName: String, recentMessages: [String]) -> URL? {
        let subject = "Denúncia iXadrez — sala \(roomCode ?? "?")"
        let quoted = recentMessages.suffix(10).map { "> \($0)" }.joined(separator: "\n")
        let body = """
        Sala: \(roomCode ?? "?")
        Adversário: \(opponentName)
        Data: \(ISO8601DateFormatter().string(from: Date()))

        Mensagens recentes do adversário:
        \(quoted.isEmpty ? "(nenhuma)" : quoted)

        Descreve o problema:

        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = reportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        return components.url
    }
}
