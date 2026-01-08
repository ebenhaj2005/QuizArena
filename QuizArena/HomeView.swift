import SwiftUI

struct HomeView: View {
    @StateObject private var auth = AuthService()
    @StateObject private var lobbyVM = LobbyViewModel()

    @State private var name = ""
    @State private var joinCode = ""
    @State private var goLobby = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Jij") {
                    TextField("Naam", text: $name)
                }

                Section("Host") {
                    Button("Maak room") {
                        Task {
                            await auth.signInIfNeeded()
                            guard let uid = auth.uid else { return }
                            await lobbyVM.host(uid: uid, name: name.isEmpty ? "Player" : name)
                            goLobby = lobbyVM.roomId != nil
                        }
                    }
                }

                Section("Join") {
                    TextField("Room code", text: $joinCode)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)


                    Button("Join room") {
                        Task {
                            await auth.signInIfNeeded()
                            guard let uid = auth.uid else { return }
                            await lobbyVM.join(uid: uid, name: name.isEmpty ? "Player" : name, code: joinCode)
                            goLobby = lobbyVM.roomId != nil
                        }
                    }
                }
            }
            .navigationTitle("QuizArena")
            .navigationDestination(isPresented: $goLobby) {
                LobbyView(lobbyVM: lobbyVM)
            }
        }
        .task { await auth.signInIfNeeded() }
    }
}
