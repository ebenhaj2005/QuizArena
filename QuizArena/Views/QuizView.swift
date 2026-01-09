import SwiftUI
import CoreData

struct QuizView: View {
    let roomId: String
    let roomCode: String
    let myUid: String
    let hostId: String

    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: QuizViewModel
    
    @State private var showLeaveConfirm = false

    init(roomId: String, roomCode: String, myUid: String, hostId: String) {
        self.roomId = roomId
        self.roomCode = roomCode
        self.myUid = myUid
        self.hostId = hostId
        _vm = StateObject(wrappedValue: QuizViewModel(roomId: roomId, roomCode: roomCode, myUid: myUid, hostId: hostId))
    }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.orange.opacity(0.3), Color.red.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Room: \(roomCode)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Vraag \(vm.currentIndex + 1) van \(vm.questions.count)")
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        // Timer
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                            Circle()
                                .trim(from: 0, to: CGFloat(vm.timeLeft) / 30.0)
                                .stroke(
                                    vm.timeLeft > 10 ? Color.green : Color.red,
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 0.25), value: vm.timeLeft)
                            
                            Text("\(vm.timeLeft)")
                                .font(.title2.bold())
                                .monospacedDigit()
                        }
                        .frame(width: 60, height: 60)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                
                if vm.questions.isEmpty && vm.status != "finished" {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading vragen…")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else if vm.status == "finished" {
                    PodiumView(players: vm.leaderboardPlayers)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            let q = vm.questions[min(vm.currentIndex, vm.questions.count - 1)]
                            
                            // Question card
                            VStack(spacing: 16) {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.blue)
                                
                                Text(q.text)
                                    .font(.title2.bold())
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.1), radius: 10)
                            
                            // Answers
                            VStack(spacing: 12) {
                                ForEach(Array(q.answers.enumerated()), id: \.offset) { idx, ans in
                                    AnswerButton(
                                        text: ans,
                                        index: idx,
                                        isSelected: vm.selectedIndex == idx,
                                        isCorrect: vm.status == "reveal" && idx == q.correctIndex,
                                        isWrong: vm.status == "reveal" && vm.selectedIndex == idx && idx != q.correctIndex,
                                        isLocked: vm.locked || vm.status != "inGame"
                                    ) {
                                        Task { await vm.submit(answerIndex: idx) }
                                    }
                                }
                            }
                            
                            if vm.status == "reveal" {
                                VStack(spacing: 8) {
                                    Image(systemName: vm.selectedIndex == q.correctIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundStyle(vm.selectedIndex == q.correctIndex ? .green : .red)
                                    
                                    Text(vm.selectedIndex == q.correctIndex ? "Correct!" : "Helaas!")
                                        .font(.title2.bold())
                                        .foregroundStyle(vm.selectedIndex == q.correctIndex ? .green : .red)
                                    
                                    Text("Juiste antwoord: \(q.answers[q.correctIndex])")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(16)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showLeaveConfirm = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Verlaat")
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .alert("Game verlaten?", isPresented: $showLeaveConfirm) {
            Button("Annuleer", role: .cancel) { }
            Button("Verlaat", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("Weet je zeker dat je de game wilt verlaten? Je score gaat verloren.")
        }
        .onAppear {
            vm.bindContextIfNeeded(moc)
            vm.startListening()
        }
    }
}

struct AnswerButton: View {
    let text: String
    let index: Int
    let isSelected: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let isLocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(["A", "B", "C", "D"][index])
                    .font(.title3.bold())
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(backgroundColor)
                    )
                    .foregroundStyle(.white)
                
                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if isSelected && !isCorrect && !isWrong {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
                if isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if isWrong {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .background(backgroundForState)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 0)
            )
        }
        .disabled(isLocked)
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        if isCorrect { return .green }
        if isWrong { return .red }
        if isSelected { return .blue }
        return .gray.opacity(0.3)
    }
    
    private var backgroundForState: Color {
        if isCorrect { return .green.opacity(0.1) }
        if isWrong { return .red.opacity(0.1) }
        return Color(.systemGray6).opacity(0.5)
    }
    
    private var borderColor: Color {
        if isCorrect { return .green }
        if isWrong { return .red }
        return .blue
    }
}
