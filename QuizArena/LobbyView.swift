import SwiftUI
import FirebaseFirestore

struct LobbyView: View {
    @ObservedObject var lobbyVM: LobbyViewModel

    @State private var goQuiz = false
    @State private var roomListener: ListenerRegistration?

    var body: some View {
        VStack(spacing: 12) {
            Text("Room code: \(lobbyVM.roomCode)")
                .font(.title3)

            List {
                Section("Spelers") {
                    ForEach(Array(lobbyVM.players.enumerated()), id: \.offset) { _, p in
                        HStack {
                            Text(p.name)
                            Spacer()
                            Text("\(p.score)")
                        }
                    }
                }
            }

            if lobbyVM.isHost {
                Button("Start game") {
                    Task { await lobbyVM.startGame() }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            } else {
                Text("Wacht op host…")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)
            }
        }
        .navigationTitle("Lobby")
        .onAppear {
            lobbyVM.listenPlayers()
            startListeningRoomIfPossible()
        }
        .onChange(of: lobbyVM.roomId) {
            startListeningRoomIfPossible()
        }
        .onDisappear {
            roomListener?.remove()
            roomListener = nil
        }
        .navigationDestination(isPresented: $goQuiz) {
            QuizView(
                roomCode: lobbyVM.roomCode,
                roomId: lobbyVM.roomId ?? "",
                myUid: lobbyVM.myUid,
                hostId: lobbyVM.hostId
            )
        }
    }

    private func startListeningRoomIfPossible() {
        guard let rid = lobbyVM.roomId else { return }

        roomListener?.remove()

        roomListener = FirestoreService().listenRoom(roomId: rid) { data in
            let status = data["status"] as? String ?? "lobby"
            if status == "inGame" {
                goQuiz = true
            }
        }

        Firestore.firestore().collection("rooms").document(rid).getDocument { snap, _ in
            let status = snap?.data()?["status"] as? String ?? "lobby"
            if status == "inGame" {
                goQuiz = true
            }
        }
    }
}
