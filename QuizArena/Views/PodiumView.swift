import SwiftUI

struct PodiumView: View {
    let players: [PlayerDoc]
    
    private var sortedPlayers: [PlayerDoc] {
        players.sorted { $0.score > $1.score }
    }
    
    private var topThree: [PlayerDoc] {
        Array(sortedPlayers.prefix(3))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Trophy header
                VStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .yellow.opacity(0.5), radius: 20)
                    
                    Text("Game Afgelopen!")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    
                    Text("Geweldige prestaties!")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                
                // Podium (top 3)
                if topThree.count >= 3 {
                    HStack(alignment: .bottom, spacing: 12) {
                        // 2nd place
                        PodiumPlace(
                            player: topThree[1],
                            rank: 2,
                            height: 140,
                            color: .gray
                        )
                        
                        // 1st place
                        PodiumPlace(
                            player: topThree[0],
                            rank: 1,
                            height: 180,
                            color: .yellow
                        )
                        
                        // 3rd place
                        if topThree.count > 2 {
                            PodiumPlace(
                                player: topThree[2],
                                rank: 3,
                                height: 100,
                                color: .orange
                            )
                        }
                    }
                    .padding(.horizontal)
                } else {
                    // Less than 3 players - show simple list
                    VStack(spacing: 12) {
                        ForEach(Array(topThree.enumerated()), id: \.element.id) { index, player in
                            LeaderboardRow(player: player, rank: index + 1)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Full leaderboard
                if sortedPlayers.count > 3 {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Volledige Klassement")
                            .font(.title2.bold())
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                                LeaderboardRow(player: player, rank: index + 1)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.horizontal)
                }
                
                // Play again button
                VStack(spacing: 12) {
                    Button {
                        // Return to home - user will handle this
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Nieuwe Game")
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
                        .cornerRadius(16)
                    }
                }
                .padding()
            }
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

struct PodiumPlace: View {
    let player: PlayerDoc
    let rank: Int
    let height: CGFloat
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            // Medal
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: rank == 1 ? 80 : 60, height: rank == 1 ? 80 : 60)
                    .shadow(color: color.opacity(0.5), radius: 10)
                
                VStack(spacing: 2) {
                    Image(systemName: rank == 1 ? "crown.fill" : "medal.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                    Text("\(rank)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
            .offset(y: rank == 1 ? -20 : 0)
            
            // Player info
            VStack(spacing: 6) {
                Text(player.name)
                    .font(rank == 1 ? .headline : .subheadline)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                    Text("\(player.score)")
                        .font(.title3.bold())
                }
                .foregroundStyle(color)
            }
            .padding(.horizontal, 8)
            
            // Podium block
            VStack {
                Spacer()
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [color.opacity(0.3), color.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.5), lineWidth: 2)
            )
        }
    }
}

struct LeaderboardRow: View {
    let player: PlayerDoc
    let rank: Int
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    private var medalIcon: String {
        switch rank {
        case 1: return "crown.fill"
        case 2, 3: return "medal.fill"
        default: return "person.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [rankColor.opacity(0.8), rankColor.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                if rank <= 3 {
                    Image(systemName: medalIcon)
                        .foregroundStyle(.white)
                        .font(.title3)
                } else {
                    Text("\(rank)")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            
            // Player name
            Text(player.name)
                .font(.body.bold())
            
            Spacer()
            
            // Score
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(rankColor)
                    .font(.caption)
                Text("\(player.score)")
                    .font(.title3.bold())
                    .foregroundStyle(rankColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(rankColor.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
}
