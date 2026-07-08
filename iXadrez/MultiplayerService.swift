import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

enum MultiplayerError: Error {
    case notConfigured, roomNotFound, roomFull, roomFinished, createFailed, lobbyFull
}

struct QuickPlayResult {
    let code: String
    let isHost: Bool
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let uid: String
    let text: String
    let mine: Bool
}

/// Networking layer for Multiplayer mode: rooms, moves, chat and presence over Firestore.
/// Mirrors chess-multiplayer.js's role on web — GameViewModel never talks to Firestore directly.
@MainActor
final class MultiplayerService: ObservableObject {
    static let shared = MultiplayerService()
    static var configured: Bool {
        guard let app = FirebaseApp.app() else { return false }
        return app.options.apiKey != nil && app.options.apiKey != "REPLACE_ME"
    }

    @Published private(set) var roomCode: String? = nil
    @Published private(set) var myColor: PieceColor? = nil
    @Published private(set) var opponentOnline: Bool = false
    @Published private(set) var chatMessages: [ChatMessage] = []

    var onRemoteMove: ((Square, Square, PieceType?) -> Void)? = nil
    var onOpponentJoined: (() -> Void)? = nil
    var onGameFinished: ((String) -> Void)? = nil

    private var myUid: String? = nil
    private var role: String? = nil // "host" | "guest"
    private var appliedPly: Int = -1
    private var roomListener: ListenerRegistration? = nil
    private var movesListener: ListenerRegistration? = nil
    private var chatListener: ListenerRegistration? = nil
    private var heartbeatTimer: Timer? = nil
    private var staleTimer: Timer? = nil
    private var lastOppPresence: [String: Any]? = nil
    private var sawGuest = false

    private let codeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") // no 0/O/1/I/L
    private let presenceHeartbeat: TimeInterval = 20
    private let presenceStale: TimeInterval = 45

    private init() {}

    private func randomCode() -> String {
        String((0..<6).map { _ in codeAlphabet.randomElement()! })
    }

    private func db() -> Firestore { Firestore.firestore() }

    @discardableResult
    private func ensureSignedIn() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid { return uid }
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
    }

    private let lobbyCodes = ["LOBBYA", "LOBBYB", "LOBBYC"]

    private func freshRoomDoc(hostUid: String) -> [String: Any] {
        [
            "hostUid": hostUid, "hostColor": "w", "guestUid": NSNull(),
            "status": "waiting", "result": NSNull(),
            "createdAt": FieldValue.serverTimestamp(), "updatedAt": FieldValue.serverTimestamp(),
            "hostPresence": ["online": true, "lastSeen": FieldValue.serverTimestamp()],
            "guestPresence": ["online": false, "lastSeen": FieldValue.serverTimestamp()],
        ]
    }

    @discardableResult
    private func enterRoom(code: String, data: [String: Any]) async throws -> String {
        let uid = myUid!
        let hostUid = data["hostUid"] as? String
        let guestUid = data["guestUid"] as? String
        let hostColor = (data["hostColor"] as? String) ?? "w"
        let status = data["status"] as? String

        if hostUid == uid {
            role = "host"
            myColor = PieceColor(rawValue: hostColor)
        } else if guestUid == uid {
            role = "guest"
            myColor = hostColor == "w" ? .black : .white
        } else if guestUid == nil {
            if status == "finished" { throw MultiplayerError.roomFinished }
            do {
                try await db().collection("rooms").document(code).updateData([
                    "guestUid": uid, "status": "active",
                    "guestPresence": ["online": true, "lastSeen": FieldValue.serverTimestamp()],
                    "updatedAt": FieldValue.serverTimestamp(),
                ])
            } catch {
                throw MultiplayerError.roomFull
            }
            role = "guest"
            myColor = hostColor == "w" ? .black : .white
        } else {
            throw MultiplayerError.roomFull
        }

        roomCode = code
        appliedPly = -1
        sawGuest = guestUid != nil || role == "guest"
        opponentOnline = false
        lastOppPresence = nil
        chatMessages = []
        attachRoomListener()
        attachMovesListener()
        attachChatListener()
        startHeartbeat()
        return code
    }

    func createRoom() async throws -> String {
        guard Self.configured else { throw MultiplayerError.notConfigured }
        let uid = try await ensureSignedIn()
        for _ in 0..<6 {
            let code = randomCode()
            let ref = db().collection("rooms").document(code)
            guard let existing = try? await ref.getDocument(), !existing.exists else { continue }
            do {
                try await ref.setData(freshRoomDoc(hostUid: uid))
            } catch { continue }
            return try await joinRoom(code)
        }
        throw MultiplayerError.createFailed
    }

    func joinRoom(_ code: String) async throws -> String {
        guard Self.configured else { throw MultiplayerError.notConfigured }
        let uid = try await ensureSignedIn()
        myUid = uid
        let ref = db().collection("rooms").document(code)
        guard let snap = try? await ref.getDocument(), snap.exists, let data = snap.data() else {
            throw MultiplayerError.roomNotFound
        }
        return try await enterRoom(code: code, data: data)
    }

    /// Joins (or claims/recycles) the first available room in the fixed public lobby pool, so two
    /// people can play without coordinating a code: whoever arrives first waits as host, whoever
    /// arrives second joins immediately as guest and the game starts right away.
    func quickPlay() async throws -> QuickPlayResult {
        guard Self.configured else { throw MultiplayerError.notConfigured }
        let uid = try await ensureSignedIn()
        myUid = uid
        for code in lobbyCodes {
            let ref = db().collection("rooms").document(code)
            let snap = try? await ref.getDocument()
            let data: [String: Any]? = (snap?.exists == true) ? snap?.data() : nil

            if data == nil || (data?["status"] as? String) == "finished" {
                do {
                    try await ref.setData(freshRoomDoc(hostUid: uid))
                } catch { continue } // someone else claimed/recycled this slot first — try the next one
                try await enterRoom(code: code, data: freshRoomDoc(hostUid: uid))
                return QuickPlayResult(code: code, isHost: true)
            }
            if let data, (data["hostUid"] as? String) == uid || (data["guestUid"] as? String) == uid {
                try await enterRoom(code: code, data: data) // reconnecting to my own quick-play game
                return QuickPlayResult(code: code, isHost: role == "host")
            }
            if let data, (data["status"] as? String) == "waiting", (data["guestUid"] as? String) == nil {
                do {
                    try await enterRoom(code: code, data: data)
                } catch { continue }
                return QuickPlayResult(code: code, isHost: false)
            }
            // occupied by two other players — try the next pool slot
        }
        throw MultiplayerError.lobbyFull
    }

    private func attachRoomListener() {
        roomListener?.remove()
        guard let code = roomCode else { return }
        roomListener = db().collection("rooms").document(code).addSnapshotListener { [weak self] snap, _ in
            guard let self, let data = snap?.data() else { return }
            Task { @MainActor in self.handleRoomUpdate(data) }
        }
        staleTimer?.invalidate()
        staleTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.recomputePresence() }
        }
    }

    private func handleRoomUpdate(_ data: [String: Any]) {
        let guestUid = data["guestUid"] as? String
        if guestUid != nil, !sawGuest {
            sawGuest = true
            onOpponentJoined?()
        }
        if let status = data["status"] as? String, status == "finished", let result = data["result"] as? String {
            onGameFinished?(result)
        }
        lastOppPresence = (role == "host" ? data["guestPresence"] : data["hostPresence"]) as? [String: Any]
        recomputePresence()
    }

    private func recomputePresence() {
        var online = false
        if let p = lastOppPresence, (p["online"] as? Bool) == true, let ts = p["lastSeen"] as? Timestamp {
            online = Date().timeIntervalSince(ts.dateValue()) < presenceStale
        }
        if online != opponentOnline { opponentOnline = online }
    }

    private func attachMovesListener() {
        movesListener?.remove()
        guard let code = roomCode else { return }
        movesListener = db().collection("rooms").document(code).collection("moves")
            .order(by: "ply")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let changes = snap?.documentChanges else { return }
                Task { @MainActor in
                    for change in changes where change.type == .added {
                        self.handleMoveDoc(change.document.data())
                    }
                }
            }
    }

    private func handleMoveDoc(_ d: [String: Any]) {
        guard let ply = d["ply"] as? Int, ply > appliedPly else { return }
        appliedPly = ply
        if (d["by"] as? String) == myUid { return } // my own move, applied locally already
        guard let fromMap = d["from"] as? [String: Any], let toMap = d["to"] as? [String: Any],
              let fr = fromMap["r"] as? Int, let fc = fromMap["c"] as? Int,
              let tr = toMap["r"] as? Int, let tc = toMap["c"] as? Int else { return }
        let promotion = (d["promotion"] as? String).flatMap { PieceType(rawValue: $0) }
        onRemoteMove?(Square(r: fr, c: fc), Square(r: tr, c: tc), promotion)
    }

    private func attachChatListener() {
        chatListener?.remove()
        guard let code = roomCode else { return }
        chatListener = db().collection("rooms").document(code).collection("chat")
            .order(by: "sentAt")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let changes = snap?.documentChanges else { return }
                Task { @MainActor in
                    for change in changes where change.type == .added {
                        let d = change.document.data()
                        guard let uid = d["uid"] as? String, let text = d["text"] as? String else { continue }
                        self.chatMessages.append(ChatMessage(uid: uid, text: text, mine: uid == self.myUid))
                    }
                }
            }
    }

    private func presenceField() -> String { role == "host" ? "hostPresence" : "guestPresence" }

    private func sendHeartbeat(online: Bool) {
        guard let code = roomCode else { return }
        db().collection("rooms").document(code).updateData([
            presenceField(): ["online": online, "lastSeen": FieldValue.serverTimestamp()],
            "updatedAt": FieldValue.serverTimestamp(),
        ])
    }

    private func startHeartbeat() {
        sendHeartbeat(online: true)
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: presenceHeartbeat, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sendHeartbeat(online: true) }
        }
    }

    func sendMove(from: Square, to: Square, promotion: PieceType?) {
        guard let code = roomCode, let uid = myUid else { return }
        let ply = appliedPly + 1
        let plyId = String(format: "%04d", ply)
        db().collection("rooms").document(code).collection("moves").document(plyId).setData([
            "ply": ply,
            "from": ["r": from.r, "c": from.c],
            "to": ["r": to.r, "c": to.c],
            "promotion": promotion?.rawValue as Any? ?? NSNull(),
            "by": uid,
            "playedAt": FieldValue.serverTimestamp(),
        ])
    }

    func sendChat(_ text: String) {
        guard let code = roomCode, let uid = myUid else { return }
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))
        guard !trimmed.isEmpty else { return }
        db().collection("rooms").document(code).collection("chat").addDocument(data: [
            "uid": uid, "text": trimmed, "sentAt": FieldValue.serverTimestamp(),
        ])
    }

    func resign() {
        guard let code = roomCode, let color = myColor else { return }
        db().collection("rooms").document(code).updateData([
            "status": "finished", "result": "resign-" + color.rawValue, "updatedAt": FieldValue.serverTimestamp(),
        ])
    }

    func leaveRoom() {
        sendHeartbeat(online: false)
        roomListener?.remove(); roomListener = nil
        movesListener?.remove(); movesListener = nil
        chatListener?.remove(); chatListener = nil
        heartbeatTimer?.invalidate(); heartbeatTimer = nil
        staleTimer?.invalidate(); staleTimer = nil
        roomCode = nil
        role = nil
        myColor = nil
        appliedPly = -1
        opponentOnline = false
        lastOppPresence = nil
        sawGuest = false
        chatMessages = []
    }
}
