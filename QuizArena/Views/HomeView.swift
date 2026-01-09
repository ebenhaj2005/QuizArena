import SwiftUI

struct HomeView: View {
    @StateObject private var auth = AuthService()
    @StateObject private var lobbyVM = LobbyViewModel()

    @State private var name = ""
    @State private var joinCode = ""

    @State private var goLobby = false
    @State private var goOffline = false
    @State private var goMap = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.2), radius: 10)
                            
                            Text("QuizArena")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text("Test je kennis, daag vrienden uit")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                        
                        // Name input card
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Jouw naam", systemImage: "person.fill")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            TextField("Naam", text: $name)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.1), radius: 10)
                        
                        // Host card
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .font(.title2)
                                    .foregroundStyle(.yellow)
                                Text("Host een game")
                                    .font(.title3.bold())
                                Spacer()
                            }
                            
                            Text("Maak een nieuwe room en nodig vrienden uit")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button {
                                Task {
                                    await auth.signInIfNeeded()
                                    guard let uid = auth.uid else { return }
                                    await lobbyVM.createRoom(uid: uid, name: name.isEmpty ? "Player" : name)
                                    goLobby = lobbyVM.roomId != nil
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Maak Room")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.1), radius: 10)
                        
                        // Join card
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                                Text("Join een game")
                                    .font(.title3.bold())
                                Spacer()
                            }
                            
                            Text("Voer de room code in om mee te spelen")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            TextField("Room code", text: $joinCode)
                                .textFieldStyle(.plain)
                                .keyboardType(.numberPad)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            
                            Button {
                                Task {
                                    await auth.signInIfNeeded()
                                    guard let uid = auth.uid else { return }
                                    await lobbyVM.joinRoom(uid: uid, name: name.isEmpty ? "Player" : name, code: joinCode)
                                    goLobby = lobbyVM.roomId != nil
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Join Room")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.1), radius: 10)
                        
                        // Extra features
                        VStack(spacing: 12) {
                            Text("Extra functies")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(.white)
                            
                            HStack(spacing: 12) {
                                NavigationLink(destination: OfflineQuestionsView()) {
                                    FeatureCard(
                                        icon: "wifi.slash",
                                        title: "Offline",
                                        color: .orange
                                    )
                                }
                                
                                NavigationLink(destination: MapScreen()) {
                                    FeatureCard(
                                        icon: "map.fill",
                                        title: "Kaart",
                                        color: .red
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $goLobby) {
                LobbyView(lobbyVM: lobbyVM)
            }
        }
        .task { await auth.signInIfNeeded() }
    }
}

// Helper view for feature cards
struct FeatureCard: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}
