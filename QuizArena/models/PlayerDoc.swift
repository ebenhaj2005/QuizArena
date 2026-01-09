import Foundation
import FirebaseFirestore

struct PlayerDoc: Identifiable, Hashable {
    let id: String
    let name: String
    let score: Int
    let joinedAt: TimeInterval

    init(id: String, name: String, score: Int = 0, joinedAt: TimeInterval = Date().timeIntervalSince1970) {
        self.id = id
        self.name = name
        self.score = score
        self.joinedAt = joinedAt
    }

    init?(snapshot: DocumentSnapshot) {
        guard let data = snapshot.data() else { return nil }
        let name = data["name"] as? String ?? "Player"
        let score = data["score"] as? Int ?? 0

        let joinedAt: TimeInterval
        if let ts = data["joinedAt"] as? Timestamp {
            joinedAt = ts.dateValue().timeIntervalSince1970
        } else if let t = data["joinedAt"] as? Double {
            joinedAt = t
        } else {
            joinedAt = 0
        }

        self.id = snapshot.documentID
        self.name = name
        self.score = score
        self.joinedAt = joinedAt
    }
}
