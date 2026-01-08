import SwiftUI
import FirebaseCore

@main
struct QuizArenaApp: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
