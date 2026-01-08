import SwiftUI

struct PodiumView: View {
    let players: [PlayerDoc]   // name, score, joinedAt

    private var sorted: [PlayerDoc] {
        players.sorted { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.joinedAt < b.joinedAt
        }
    }

    private func player(at index: Int) -> PlayerDoc? {
        guard index >= 0 && index < sorted.count else { return nil }
        return sorted[index]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("🏁 Game Over")
                    .font(.largeTitle).bold()

                if let winner = player(at: 0) {
                    VStack(spacing: 6) {
                        Text("🏆 Winner")
                            .font(.headline)
                        Text(winner.name)
                            .font(.title).bold()
                        Text("Score: \(winner.score)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Podium blocks (Top 3)
                HStack(alignment: .bottom, spacing: 12) {
                    podiumCard(rank: 2, emoji: "🥈", height: 120)
                    podiumCard(rank: 1, emoji: "🥇", height: 160)
                    podiumCard(rank: 3, emoji: "🥉", height: 100)
                }
                .frame(maxWidth: .infinity)

                // Full leaderboard
                VStack(alignment: .leading, spacing: 10) {
                    Text("Leaderboard")
                        .font(.headline)

                    ForEach(Array(sorted.enumerated()), id: \.offset) { i, p in
                        HStack {
                            Text("#\(i + 1)")
                                .frame(width: 40, alignment: .leading)
                                .foregroundStyle(.secondary)

                            Text(p.name)
                            Spacer()
                            Text("\(p.score)")
                                .bold()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Podium")
    }

    @ViewBuilder
    private func podiumCard(rank: Int, emoji: String, height: CGFloat) -> some View {
        let p = player(at: rank - 1)

        VStack(spacing: 6) {
            Text(emoji)
                .font(.largeTitle)

            Text(p?.name ?? "—")
                .font(.headline)
                .lineLimit(1)

            Text("\(p?.score ?? 0)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
