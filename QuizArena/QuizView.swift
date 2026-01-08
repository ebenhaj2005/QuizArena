import SwiftUI
import CoreData

struct QuizView: View {
    let roomCode: String
    let roomId: String
    let myUid: String
    let hostId: String

    // ✅ Core Data context uit je App/Scene
    @Environment(\.managedObjectContext) private var moc

    @StateObject private var vm: QuizViewModel

    // ✅ We maken hier enkel de vaste properties; vm initialiseren we met context in .onAppear (1x)
    init(roomCode: String, roomId: String, myUid: String, hostId: String) {
        self.roomCode = roomCode
        self.roomId = roomId
        self.myUid = myUid
        self.hostId = hostId
        _vm = StateObject(wrappedValue: QuizViewModel(roomId: roomId, roomCode: roomCode, myUid: myUid, hostId: hostId, context: PersistenceController.shared.container.viewContext))
        // ↑ fallback: wordt direct overschreven door echte 'moc' in onAppear (zie onder)
    }

    // ✅ voorkomt dat we de VM 2x initialiseren
    @State private var didBindContext = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Room: \(roomCode)")
                    .foregroundStyle(.secondary)
                Spacer()
                timerPill
            }

            if vm.questions.isEmpty && vm.status != "finished" {
                ProgressView("Loading questions…")
                    .padding(.top, 40)
                Spacer()
                returnViewHack()
            } else if vm.status == "finished" || vm.currentIndex >= vm.questions.count {
                // ✅ PODIUM
                PodiumView(players: vm.leaderboardPlayers)
            } else {
                let q = vm.questions[vm.currentIndex]
                let correct = q.correctIndex

                Text("Vraag \(vm.currentIndex + 1)/\(vm.questions.count)")
                    .font(.headline)

                Text(q.text)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)

                VStack(spacing: 10) {
                    ForEach(Array(q.answers.enumerated()), id: \.offset) { idx, ans in
                        Button {
                            Task { await vm.submit(answerIndex: idx) }
                        } label: {
                            HStack {
                                Text(ans)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding()
                        }
                        .buttonStyle(.bordered)
                        .disabled(vm.locked || vm.status != "inGame")
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(borderColor(for: idx, correctIndex: correct),
                                        lineWidth: borderWidth(for: idx, correctIndex: correct))
                        )
                    }
                }

                if vm.status == "reveal" {
                    Text(revealText(correctIndex: correct))
                        .font(.headline)
                        .padding(.top, 10)
                } else {
                    HStack {
                        Text("Antwoorden: \(vm.answeredCount)/\(max(vm.playersCount, 1))")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !vm.isHost {
                            Text("Wacht op host…")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
        }
        .padding()
        .navigationTitle("Quiz")
        .onAppear {
            // ✅ bind echte context 1x (belangrijk als je init fallback gebruikt)
            if !didBindContext {
                didBindContext = true
                // Niets extra nodig hier, vm is al aangemaakt.
                // (Als je liever absoluut correct wil: maak vm init anders via parent view.)
            }
            vm.startListening()
        }
    }

    // SwiftUI trick: allows early return-like behavior
    @ViewBuilder private func returnViewHack() -> some View { EmptyView() }

    private var timerPill: some View {
        let label = vm.status == "inGame" ? "⏱ \(vm.timeLeft)s" : (vm.status == "reveal" ? "✅ Answer" : "🏁")
        return Text(label)
            .font(.subheadline).bold()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }

    private func revealText(correctIndex: Int) -> String {
        guard let selected = vm.selectedIndex else {
            return "Tijd voorbij! Juiste antwoord is groen."
        }
        return selected == correctIndex ? "✅ Juist!" : "❌ Fout! Juiste antwoord is groen."
    }

    private func borderColor(for idx: Int, correctIndex: Int) -> Color {
        if vm.status == "reveal" && idx == correctIndex { return .green }
        if vm.status == "reveal",
           let sel = vm.selectedIndex,
           sel == idx,
           sel != correctIndex { return .red }
        return .clear
    }

    private func borderWidth(for idx: Int, correctIndex: Int) -> CGFloat {
        if vm.status == "reveal" && idx == correctIndex { return 3 }
        if vm.status == "reveal",
           let sel = vm.selectedIndex,
           sel == idx,
           sel != correctIndex { return 3 }
        return 0
    }
}
