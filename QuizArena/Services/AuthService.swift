import Foundation
import Combine
import FirebaseAuth


@MainActor
final class AuthService: ObservableObject {
    @Published var uid: String? = nil

    func signInIfNeeded() async {
        if let u = Auth.auth().currentUser {
            uid = u.uid
            return
        }
        do {
            let res = try await Auth.auth().signInAnonymously()
            uid = res.user.uid
        } catch {
            print("Auth error:", error)
        }
    }
}

