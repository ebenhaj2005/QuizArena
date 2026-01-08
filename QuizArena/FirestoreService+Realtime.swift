import Foundation
import FirebaseFirestore

extension FirestoreService {

    // ✅ Realtime room listener (no db property needed)
    func rtListenRoom(roomId: String, onChange: @escaping ([String: Any]) -> Void) -> ListenerRegistration {
        Firestore.firestore()
            .collection("rooms")
            .document(roomId)
            .addSnapshotListener { snap, _ in
                guard let data = snap?.data() else { return }
                onChange(data)
            }
    }

    // ✅ Realtime players count
    func rtListenPlayersCount(roomId: String, onChange: @escaping (Int) -> Void) -> ListenerRegistration {
        Firestore.firestore()
            .collection("rooms")
            .document(roomId)
            .collection("players")
            .addSnapshotListener { snap, _ in
                onChange(snap?.documents.count ?? 0)
            }
    }

    // ✅ Realtime answers count for current question
    func rtListenAnswersCount(roomId: String, questionIndex: Int, onChange: @escaping (Int) -> Void) -> ListenerRegistration {
        Firestore.firestore()
            .collection("rooms")
            .document(roomId)
            .collection("answers")
            .document("\(questionIndex)")
            .collection("players")
            .addSnapshotListener { snap, _ in
                onChange(snap?.documents.count ?? 0)
            }
    }
}
