import Foundation
import FirebaseFirestore

final class FirestoreService {

    private let db = Firestore.firestore()
    private let roomsCol = "rooms"

    // MARK: - Realtime listeners

    /// Luister naar room document (rooms/{roomId})
    @discardableResult
    func listenRoom(roomId: String,
                    onChange: @escaping ([String: Any]) -> Void) -> ListenerRegistration {
        db.collection(roomsCol).document(roomId)
            .addSnapshotListener { snap, err in
                if let err {
                    print("❌ listenRoom error:", err)
                    return
                }
                guard let data = snap?.data() else { return }
                onChange(data)
            }
    }

    /// Luister naar players (rooms/{roomId}/players)
    @discardableResult
    func listenPlayers(roomId: String,
                       onChange: @escaping ([PlayerDoc]) -> Void) -> ListenerRegistration {
        db.collection(roomsCol).document(roomId).collection("players")
            .addSnapshotListener { snap, err in
                if let err {
                    print("❌ listenPlayers error:", err)
                    onChange([])
                    return
                }
                let docs = snap?.documents ?? []
                let players = docs.compactMap { PlayerDoc(snapshot: $0) }
                    .sorted { $0.joinedAt < $1.joinedAt }
                onChange(players)
            }
    }

    /// Luister enkel naar aantal players
    @discardableResult
    func listenPlayersCount(roomId: String,
                            onChange: @escaping (Int) -> Void) -> ListenerRegistration {
        db.collection(roomsCol).document(roomId).collection("players")
            .addSnapshotListener { snap, err in
                if let err {
                    print("❌ listenPlayersCount error:", err)
                    onChange(0)
                    return
                }
                onChange(snap?.documents.count ?? 0)
            }
    }

    /// Luister naar aantal antwoorden voor een specifieke vraag
    @discardableResult
    func listenAnswersCount(roomId: String,
                           questionIndex: Int,
                           onChange: @escaping (Int) -> Void) -> ListenerRegistration {
        db.collection(roomsCol)
            .document(roomId)
            .collection("answers")
            .document(String(questionIndex))
            .collection("players")
            .addSnapshotListener { snap, err in
                if let err {
                    print("❌ listenAnswersCount error:", err)
                    onChange(0)
                    return
                }
                onChange(snap?.documents.count ?? 0)
            }
    }

    // MARK: - Room actions

    func setRoomStatus(roomId: String, status: String) async throws {
        try await db.collection(roomsCol).document(roomId).updateData([
            "status": status
        ])
    }

    func setQuestionStartedNow(roomId: String) async throws {
        try await db.collection(roomsCol).document(roomId).updateData([
            "questionStartedAt": Date().timeIntervalSince1970
        ])
    }

    /// Houd deze signature zodat "amount" calls niet crashen (ook als je het niet gebruikt).
    func startGame(roomId: String, amount: Int = 10) async throws {
        try await db.collection(roomsCol).document(roomId).updateData([
            "status": "inGame",
            "currentQuestionIndex": 0,
            "questionStartedAt": Date().timeIntervalSince1970
        ])
    }

    func advanceToNextQuestion(roomId: String) async throws {
        // increment currentQuestionIndex
        try await db.collection(roomsCol).document(roomId).updateData([
            "currentQuestionIndex": FieldValue.increment(Int64(1)),
            "questionStartedAt": Date().timeIntervalSince1970
        ])
    }

    func advanceToNextQuestion(roomId: String, nextIndex: Int) async throws {
        try await db.collection(roomsCol).document(roomId).updateData([
            "currentQuestionIndex": nextIndex,
            "questionStartedAt": Date().timeIntervalSince1970
        ])
    }

    /// Advance met finished parameter
    func advanceToNextQuestion(roomId: String,
                              nextIndex: Int,
                              finished: Bool) async throws {
        if finished {
            try await db.collection(roomsCol).document(roomId).updateData([
                "status": "finished",
                "currentQuestionIndex": nextIndex
            ])
        } else {
            try await db.collection(roomsCol).document(roomId).updateData([
                "currentQuestionIndex": nextIndex,
                "status": "inGame",
                "questionStartedAt": Date().timeIntervalSince1970
            ])
        }
    }

    // MARK: - Answers / scoring

    /// Slaat antwoord op onder: rooms/{roomId}/answers/{questionIndex}/players/{playerId}
    func submitAnswer(roomId: String,
                      questionIndex: Int,
                      playerId: String,
                      answerIndex: Int) async throws {
        let answersRef = db.collection(roomsCol)
            .document(roomId)
            .collection("answers")
            .document(String(questionIndex))
            .collection("players")
            .document(playerId)

        try await answersRef.setData([
            "answerIndex": answerIndex,
            "submittedAt": Timestamp()
        ], merge: true)
    }

    /// Simpele scoring: als correct -> +1 op speler score (idempotent via "scored" flag per question)
    /// Verwacht dat je correctIndex zelf doorgeeft (van je questions data).
    func scoreCurrentQuestionIfNeeded(roomId: String,
                                      questionIndex: Int,
                                      correctIndex: Int) async throws {
        let base = db.collection(roomsCol).document(roomId)
        let answersPlayers = base.collection("answers")
            .document(String(questionIndex))
            .collection("players")

        // haal alle antwoorden op
        let snap = try await answersPlayers.getDocuments()
        let docs = snap.documents

        for doc in docs {
            let data = doc.data()
            let alreadyScored = data["scored"] as? Bool ?? false
            if alreadyScored { continue }

            let ans = data["answerIndex"] as? Int ?? -1
            let isCorrect = (ans == correctIndex)
            let playerId = doc.documentID

            // markeer als scored
            try await doc.reference.setData(["scored": true], merge: true)

            // score update
            if isCorrect {
                try await base.collection("players").document(playerId).updateData([
                    "score": FieldValue.increment(Int64(1))
                ])
            }
        }
    }

    // MARK: - Question Sets

    /// Haal een question set op
    func fetchQuestionSet(questionSetId: String) async throws -> [QuizQuestion] {
        let doc = try await db.collection("questionSets").document(questionSetId).getDocument()
        
        guard let data = doc.data() else {
            return []
        }
        
        guard let questionsData = data["questions"] as? [[String: Any]] else {
            return []
        }
        
        return questionsData.compactMap { dict in
            guard let text = dict["text"] as? String,
                  let answers = dict["answers"] as? [String],
                  let correctIndex = dict["correctIndex"] as? Int else {
                return nil
            }
            
            let id = dict["id"] as? String ?? UUID().uuidString
            return QuizQuestion(id: id, text: text, answers: answers, correctIndex: correctIndex)
        }
    }

    // MARK: - Optional helpers (voor compatibiliteit)

    /// Join via roomCode (rooms where roomCode == code)
    func joinRoom(code: String,
                 playerId: String,
                 playerName: String) async throws -> (roomId: String, hostId: String) {

        let qs = try await db.collection(roomsCol)
            .whereField("roomCode", isEqualTo: code)
            .limit(to: 1)
            .getDocuments()

        guard let room = qs.documents.first else {
            throw NSError(domain: "FirestoreService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Room niet gevonden."
            ])
        }

        let rid = room.documentID
        let hostId = room.data()["hostId"] as? String ?? ""

        try await db.collection(roomsCol)
            .document(rid)
            .collection("players")
            .document(playerId)
            .setData([
                "name": playerName,
                "score": 0,
                "joinedAt": Timestamp()
            ], merge: true)

        return (rid, hostId)
    }
}
