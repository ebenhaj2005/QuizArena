import Foundation
import FirebaseFirestore

// MARK: - Models
struct PlayerDoc {
    var name: String
    var score: Int
    var joinedAt: TimeInterval
}

final class FirestoreService {
    private let db = Firestore.firestore()

    // MARK: Room creation / join
    func createRoom(hostId: String, code: String) async throws -> String {
        let roomId = UUID().uuidString
        try await db.collection("rooms").document(roomId).setData([
            "code": code,
            "hostId": hostId,
            "status": "lobby",                 // lobby | inGame | reveal | finished
            "currentQuestionIndex": 0,
            "questionSetId": NSNull(),
            "questionStartedAt": NSNull(),
            "lastScoredIndex": -1              // prevents double scoring
        ])
        return roomId
    }

    func findRoomId(byCode code: String) async throws -> String {
        let snap = try await db.collection("rooms")
            .whereField("code", isEqualTo: code)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snap.documents.first else { throw NSError(domain: "Room", code: 404) }
        return doc.documentID
    }

    func joinRoom(roomId: String, playerId: String, name: String) async throws {
        try await db.collection("rooms").document(roomId)
            .collection("players").document(playerId)
            .setData([
                "name": name,
                "score": 0,
                "joinedAt": Date().timeIntervalSince1970
            ])
    }

    func listenPlayers(roomId: String, onChange: @escaping ([PlayerDoc]) -> Void) -> ListenerRegistration {
        db.collection("rooms").document(roomId).collection("players")
            .addSnapshotListener { snap, _ in
                guard let docs = snap?.documents else { return }
                let players: [PlayerDoc] = docs.compactMap { d in
                    let data = d.data()
                    guard let name = data["name"] as? String,
                          let score = data["score"] as? Int,
                          let joinedAt = data["joinedAt"] as? TimeInterval else { return nil }
                    return PlayerDoc(name: name, score: score, joinedAt: joinedAt)
                }
                onChange(players.sorted { $0.joinedAt < $1.joinedAt })
            }
    }

    func listenPlayersCount(roomId: String, onChange: @escaping (Int) -> Void) -> ListenerRegistration {
        db.collection("rooms").document(roomId).collection("players")
            .addSnapshotListener { snap, _ in
                onChange(snap?.documents.count ?? 0)
            }
    }

    // MARK: Room realtime
    func listenRoom(roomId: String, onChange: @escaping ([String: Any]) -> Void) -> ListenerRegistration {
        db.collection("rooms").document(roomId).addSnapshotListener { snap, _ in
            guard let data = snap?.data() else { return }
            onChange(data)
        }
    }

    // MARK: QuestionSets
    func uploadQuestionSet(questionSetId: String, questions: [QuizQuestion]) async throws {
        let payload: [[String: Any]] = questions.map { q in
            [
                "id": q.id,
                "text": q.text,
                "answers": q.answers,
                "correctIndex": q.correctIndex
            ]
        }

        try await db.collection("questionSets").document(questionSetId).setData([
            "createdAt": Date().timeIntervalSince1970,
            "questions": payload
        ])
    }

    func fetchQuestionSet(questionSetId: String) async throws -> [QuizQuestion] {
        let snap = try await db.collection("questionSets").document(questionSetId).getDocument()
        guard let data = snap.data(),
              let arr = data["questions"] as? [[String: Any]] else { return [] }

        return arr.compactMap { d in
            guard let id = d["id"] as? String,
                  let text = d["text"] as? String,
                  let answers = d["answers"] as? [String],
                  let correctIndex = d["correctIndex"] as? Int else { return nil }
            return QuizQuestion(id: id, text: text, answers: answers, correctIndex: correctIndex)
        }
    }

    // MARK: Start / advance game
    func startRoomGame(roomId: String, questionSetId: String) async throws {
        try await db.collection("rooms").document(roomId).updateData([
            "status": "inGame",
            "questionSetId": questionSetId,
            "currentQuestionIndex": 0,
            "questionStartedAt": Date().timeIntervalSince1970
        ])
    }

    func setRoomStatus(roomId: String, status: String) async throws {
        try await db.collection("rooms").document(roomId).updateData([
            "status": status
        ])
    }

    func advanceToNextQuestion(roomId: String, nextIndex: Int, finished: Bool) async throws {
        if finished {
            try await db.collection("rooms").document(roomId).updateData([
                "status": "finished"
            ])
        } else {
            try await db.collection("rooms").document(roomId).updateData([
                "status": "inGame",
                "currentQuestionIndex": nextIndex,
                "questionStartedAt": Date().timeIntervalSince1970
            ])
        }
    }

    // MARK: Answers
    func submitAnswer(roomId: String, questionIndex: Int, playerId: String, answerIndex: Int) async throws {
        let docId = "\(questionIndex)_\(playerId)"
        try await db.collection("rooms").document(roomId)
            .collection("answers").document(docId)
            .setData([
                "questionIndex": questionIndex,
                "playerId": playerId,
                "answerIndex": answerIndex,
                "answeredAt": Date().timeIntervalSince1970
            ])
    }

    func listenAnswersCount(roomId: String, questionIndex: Int, onChange: @escaping (Int) -> Void) -> ListenerRegistration {
        db.collection("rooms").document(roomId)
            .collection("answers")
            .whereField("questionIndex", isEqualTo: questionIndex)
            .addSnapshotListener { snap, _ in
                onChange(snap?.documents.count ?? 0)
            }
    }

    // MARK: Scoring (host-only, no transaction getDocuments)
    func scoreCurrentQuestionIfNeeded(roomId: String, questionIndex: Int, correctIndex: Int) async throws {
        let roomRef = db.collection("rooms").document(roomId)

        // 1) Check lastScoredIndex
        let roomSnap = try await roomRef.getDocument()
        let lastScored = roomSnap.data()?["lastScoredIndex"] as? Int ?? -1
        if lastScored >= questionIndex { return } // already scored

        // 2) Fetch answers for this question
        let answersSnap = try await roomRef.collection("answers")
            .whereField("questionIndex", isEqualTo: questionIndex)
            .getDocuments()

        // 3) Batch update scores
        let batch = db.batch()
        for doc in answersSnap.documents {
            let data = doc.data()
            let pid = data["playerId"] as? String ?? ""
            let ans = data["answerIndex"] as? Int ?? -999

            if !pid.isEmpty, ans == correctIndex {
                let playerRef = roomRef.collection("players").document(pid)
                batch.updateData(["score": FieldValue.increment(Int64(1))], forDocument: playerRef)
            }
        }

        // 4) Mark as scored (prevents double scoring)
        batch.updateData(["lastScoredIndex": questionIndex], forDocument: roomRef)

        try await batch.commit()
    }
}
