import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class LobbyViewModel: ObservableObject {

    // MARK: - Published UI state
    @Published var roomId: String? = nil
    @Published var roomCode: String = ""
    @Published var hostId: String = ""

    @Published var players: [PlayerDoc] = []
    @Published var playersCount: Int = 0

    @Published var status: String = "lobby"
    @Published var currentQuestionIndex: Int = 0

    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false

    // MARK: - Firestore
    private let db = Firestore.firestore()

    // MARK: - Listeners
    private var roomListener: ListenerRegistration?
    private var playersListener: ListenerRegistration?

    // MARK: - Deinit
    nonisolated deinit {
        roomListener?.remove()
        playersListener?.remove()
    }

    // MARK: - Listening
    
    func startListening() {
        stopListening()
        guard let rid = roomId else { return }

        roomListener = db.collection("rooms").document(rid)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in self.errorMessage = err.localizedDescription }
                    return
                }
                guard let data = snap?.data() else { return }

                Task { @MainActor in
                    self.status = data["status"] as? String ?? "lobby"
                    self.currentQuestionIndex = data["currentQuestionIndex"] as? Int ?? 0
                    self.hostId = data["hostId"] as? String ?? self.hostId
                    self.roomCode = data["roomCode"] as? String ?? self.roomCode
                }
            }

        playersListener = db.collection("rooms").document(rid).collection("players")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in self.errorMessage = err.localizedDescription }
                    return
                }

                let docs = snap?.documents ?? []
                let mapped = docs.compactMap { PlayerDoc(snapshot: $0) }
                    .sorted { $0.joinedAt < $1.joinedAt }

                Task { @MainActor in
                    self.players = mapped
                    self.playersCount = mapped.count
                }
            }
    }

    func stopListening() {
        roomListener?.remove()
        roomListener = nil
        playersListener?.remove()
        playersListener = nil
    }

    // MARK: - Backward compatibility wrappers
   
    /// Oud: createRoom(uid:name:amount:)
    func createRoom(uid: String, name: String, amount: Int = 10) async {
        await createRoom(hostId: uid, hostName: name)
    }

    /// Oud: joinRoom(uid:name:code:) of join(uid:name:code:)
    func joinRoom(uid: String, name: String, code: String) async {
        await joinRoom(playerId: uid, playerName: name, code: code)
    }

    /// Oud: startGame(roomId:amount:)
    func startGame(roomId: String, amount: Int = 10) async {
        self.roomId = roomId
        await startGame()
    }

    // MARK: - Main implementations

    func createRoom(hostId: String, hostName: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let code = String(Int.random(in: 1000...9999))
            let ref = db.collection("rooms").document()

            try await ref.setData([
                "roomCode": code,
                "hostId": hostId,
                "status": "lobby",
                "currentQuestionIndex": 0,
                "questionSetId": "default",  // ← Voeg dit toe
                "createdAt": Timestamp()
            ])

            try await ref.collection("players").document(hostId).setData([
                "name": hostName,
                "score": 0,
                "joinedAt": Timestamp()
            ])

            self.roomId = ref.documentID
            self.roomCode = code
            self.hostId = hostId

            startListening()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinRoom(playerId: String, playerName: String, code: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let snap = try await db.collection("rooms")
                .whereField("roomCode", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()

            guard let doc = snap.documents.first else {
                errorMessage = "Room niet gevonden."
                return
            }

            let rid = doc.documentID
            let host = doc.data()["hostId"] as? String ?? ""

            try await db.collection("rooms")
                .document(rid)
                .collection("players")
                .document(playerId)
                .setData([
                    "name": playerName,
                    "score": 0,
                    "joinedAt": Timestamp()
                ], merge: true)

            self.roomId = rid
            self.roomCode = code
            self.hostId = host

            startListening()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Host start game (zet status inGame)
    func startGame(questionSetId: String = "default") async {
        guard let rid = roomId else { return }
        errorMessage = nil

        do {
            try await db.collection("rooms").document(rid).updateData([
                "status": "inGame",
                "questionSetId": questionSetId,
                "currentQuestionIndex": 0,
                "questionStartedAt": Date().timeIntervalSince1970
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
