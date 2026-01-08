import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class LobbyViewModel: ObservableObject {

    // MARK: - Published state
    @Published var roomId: String? = nil
    @Published var roomCode: String = ""
    @Published var players: [PlayerDoc] = []

    @Published var myUid: String = ""
    @Published var hostId: String = ""
    var isHost: Bool { myUid == hostId }

    // MARK: - Services
    private let fs = FirestoreService()
    private let db = Firestore.firestore()

    private var playersListener: ListenerRegistration?

    init() {}

    deinit {
        playersListener?.remove()
    }

    // MARK: - Host
    func host(uid: String, name: String) async {
        do {
            myUid = uid
            hostId = uid

            let code = makeCode()
            roomCode = code

            let rid = try await fs.createRoom(hostId: uid, code: code)
            roomId = rid

            try await fs.joinRoom(roomId: rid, playerId: uid, name: name)
            listenPlayers()
        } catch {
            print("Host error:", error)
        }
    }

    // MARK: - Join
    func join(uid: String, name: String, code: String) async {
        do {
            myUid = uid
            roomCode = code

            let rid = try await fs.findRoomId(byCode: code)
            roomId = rid

            // hostId ophalen uit rooms/{roomId}
            let snap = try await db.collection("rooms").document(rid).getDocument()
            hostId = snap.data()?["hostId"] as? String ?? ""

            try await fs.joinRoom(roomId: rid, playerId: uid, name: name)
            listenPlayers()
        } catch {
            print("Join error:", error)
        }
    }

    // MARK: - Listen players
    func listenPlayers() {
        guard let rid = roomId else { return }
        playersListener?.remove()
        playersListener = fs.listenPlayers(roomId: rid) { [weak self] players in
            Task { @MainActor in
                self?.players = players
            }
        }
    }

    // MARK: - Start game (host only)
    /// Deze doet alles direct via Firestore (geen extra FirestoreService methods nodig)
    func startGame() async {
        guard isHost, let rid = roomId else { return }

        do {
            // 1) vragen ophalen
            let api = TriviaAPIService()
            let qs = try await api.fetchQuestions(amount: 10)

            // 2) questionSet opslaan onder rooms/{roomId}/questionSets/{qsid}
            let qsid = UUID().uuidString
            let setRef = db.collection("rooms").document(rid).collection("questionSets").document(qsid)

            let payload: [[String: Any]] = qs.map {
                [
                    "id": $0.id,
                    "text": $0.text,
                    "answers": $0.answers,
                    "correctIndex": $0.correctIndex
                ]
            }

            try await setRef.setData([
                "createdAt": Date().timeIntervalSince1970,
                "questions": payload
            ])

            // 3) room updaten: status inGame + index 0 + startedAt
            try await db.collection("rooms").document(rid).updateData([
                "status": "inGame",
                "currentQuestionIndex": 0,
                "questionSetId": qsid,
                "questionStartedAt": Date().timeIntervalSince1970
            ])

            print("✅ Game started")

        } catch {
            print("Start game error:", error)
        }
    }

    // MARK: - Utils
    private func makeCode() -> String {
        String((0..<6).map { _ in "0123456789".randomElement()! })
    }
}
