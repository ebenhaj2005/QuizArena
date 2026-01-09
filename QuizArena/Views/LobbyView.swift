import SwiftUI

struct LobbyView: View {
    @ObservedObject var lobbyVM: LobbyViewModel
    @StateObject private var auth = AuthService()
    
    @State private var showStartConfirm = false
    @State private var hasNavigatedToQuiz = false
    
    private var isHost: Bool {
        auth.uid == lobbyVM.hostId
    }
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Room code card
                    VStack(spacing: 12) {
                        Text("Room Code")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 4) {
                            ForEach(Array(lobbyVM.roomCode), id: \.self) { char in
                                Text(String(char))
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .frame(width: 60, height: 80)
                                    .background(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(12)
                            }
                        }
                        
                        Text("Deel deze code met je vrienden")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 10)
                    
                    // Players section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(.blue)
                            Text("Spelers (\(lobbyVM.playersCount))")
                                .font(.title2.bold())
                            Spacer()
                        }
                        
                        if lobbyVM.players.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "hourglass")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("Wachten op spelers...")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(lobbyVM.players) { player in
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: player.id == lobbyVM.hostId ? [.yellow, .orange] : [.blue, .purple],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 50, height: 50)
                                            
                                            Image(systemName: player.id == lobbyVM.hostId ? "crown.fill" : "person.fill")
                                                .foregroundStyle(.white)
                                                .font(.title3)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(player.name)
                                                .font(.headline)
                                            
                                            if player.id == lobbyVM.hostId {
                                                Text("Host")
                                                    .font(.caption)
                                                    .foregroundStyle(.orange)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .font(.title3)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6).opacity(0.5))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 10)
                    
                    // Start button (host only)
                    if isHost {
                        Button {
                            showStartConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Game")
                                    .fontWeight(.bold)
                            }
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: lobbyVM.playersCount >= 1 ? [.green, .mint] : [.gray],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.2), radius: 10)
                        }
                        .disabled(lobbyVM.playersCount < 1)
                        .padding(.horizontal)
                    }
                    
                    // Error message
                    if let error = lobbyVM.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                            .background(.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Lobby")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Start de game?", isPresented: $showStartConfirm) {
            Button("Annuleer", role: .cancel) { }
            Button("Start") {
                Task {
                    await lobbyVM.startGame(questionSetId: "default")
                }
            }
        } message: {
            Text("Alle spelers zijn klaar om te beginnen!")
        }
        .navigationDestination(isPresented: $hasNavigatedToQuiz) {
            if let rid = lobbyVM.roomId, let uid = auth.uid {
                QuizView(
                    roomId: rid,
                    roomCode: lobbyVM.roomCode,
                    myUid: uid,
                    hostId: lobbyVM.hostId
                )
            }
        }
        .onChange(of: lobbyVM.status) { oldValue, newValue in
            // Only navigate once when status changes to inGame
            if newValue == "inGame" && !hasNavigatedToQuiz {
                hasNavigatedToQuiz = true
            }
        }
        .task {
            await auth.signInIfNeeded()
        }
    }
}
