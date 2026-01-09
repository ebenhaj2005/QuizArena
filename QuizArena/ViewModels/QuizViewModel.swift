import Foundation
import Combine
import FirebaseFirestore
import CoreData

@MainActor
final class QuizViewModel: ObservableObject {

    // MARK: - Identity
    let roomId: String
    let roomCode: String
    let myUid: String
    let hostId: String
    var isHost: Bool { myUid == hostId }

    // MARK: - Published UI State
    @Published var questions: [QuizQuestion] = []
    @Published var status: String = "lobby"          // lobby | inGame | reveal | finished
    @Published var currentIndex: Int = 0

    @Published var timeLeft: Int = 30
    @Published var locked: Bool = false
    @Published var selectedIndex: Int? = nil

    @Published var playersCount: Int = 0
    @Published var answeredCount: Int = 0

    // Podium / leaderboard
    @Published var leaderboardPlayers: [PlayerDoc] = []

    // MARK: - Services / Listeners
    private let fs = FirestoreService()

    private var roomListener: ListenerRegistration?
    private var playersCountListener: ListenerRegistration?
    private var playersListener: ListenerRegistration?
    private var answersCountListener: ListenerRegistration?

    private var tickCancellable: AnyCancellable?

    // MARK: - Room data cache
    private var questionStartedAt: TimeInterval? = nil
    private var questionSetId: String? = nil

    // MARK: - Round control
    private var isEndingRound = false

    // MARK: - Core Data binding (offline/local storage)
    private var didBindContext = false
    private(set) var context: NSManagedObjectContext?

    func bindContextIfNeeded(_ moc: NSManagedObjectContext) {
        guard !didBindContext else { return }
        didBindContext = true
        context = moc
    }

    // MARK: - Init
    init(roomId: String, roomCode: String, myUid: String, hostId: String) {
        self.roomId = roomId
        self.roomCode = roomCode
        self.myUid = myUid
        self.hostId = hostId
    }

    // MARK: - Cleanup
    nonisolated deinit {
        roomListener?.remove()
        playersCountListener?.remove()
        playersListener?.remove()
        answersCountListener?.remove()
        tickCancellable?.cancel()
    }

    // MARK: - Start listeners
    func startListening() {

        // Players count (used for auto-next)
        playersCountListener?.remove()
        playersCountListener = fs.listenPlayersCount(roomId: roomId) { [weak self] count in
            guard let self else { return }
            Task { @MainActor in
                self.playersCount = count
                self.checkAutoProgressIfHost()
            }
        }

        // Full players list (for podium)
        playersListener?.remove()
        playersListener = fs.listenPlayers(roomId: roomId) { [weak self] players in
            guard let self else { return }
            Task { @MainActor in
                self.leaderboardPlayers = players
            }
        }

        // Room realtime listener
        roomListener?.remove()
        roomListener = fs.listenRoom(roomId: roomId) { [weak self] data in
            guard let self else { return }
            Task { @MainActor in

                let newStatus = data["status"] as? String ?? "lobby"
                let newIndex = data["currentQuestionIndex"] as? Int ?? 0
                let newQsid = data["questionSetId"] as? String
                let newStartedAt = data["questionStartedAt"] as? TimeInterval

                print("📱 DEBUG - Room data ontvangen:")
                print("   status: \(newStatus)")
                print("   currentIndex: \(newIndex)")
                print("   questionSetId: \(newQsid ?? "NIL")")
                print("   questionStartedAt: \(newStartedAt ?? 0)")
                print("   questions.count: \(self.questions.count)")

                let indexChanged = (newIndex != self.currentIndex)
                let statusChanged = (newStatus != self.status)

                self.status = newStatus
                self.currentIndex = newIndex
                self.questionSetId = newQsid
                self.questionStartedAt = newStartedAt

                // Load questions if not yet loaded
                if self.questions.isEmpty, let qsid = self.questionSetId {
                    print("📱 Probeer questions te laden van questionSetId: \(qsid)")
                    Task {
                        let qs = try? await self.fs.fetchQuestionSet(questionSetId: qsid)
                        await MainActor.run {
                            self.questions = qs ?? []
                            if self.questions.isEmpty {
                                print("⚠️ Geen questions gevonden, laden fallback...")
                                self.loadFallbackQuestions()
                            } else {
                                print("✅ \(self.questions.count) questions geladen")
                            }
                        }
                    }
                } else if self.questions.isEmpty {
                    print("⚠️ Geen questionSetId, laden fallback...")
                    self.loadFallbackQuestions()
                }

                // When question changes or we enter inGame: reset local state
                if indexChanged || (statusChanged && newStatus == "inGame") {
                    self.resetForNewQuestion()
                }

                // Listen answers count for current question
                self.startAnswersListener(questionIndex: self.currentIndex)

                // Start/update local timer tick
                self.startTickTimer()

                // If reveal/finished: lock UI
                self.syncLocalLockState()

                // Host might need to auto-progress
                self.checkAutoProgressIfHost()
            }
        }
    }

    private func loadFallbackQuestions() {
        questions = [
            QuizQuestion(
                id: "1",
                text: "Wat is de hoofdstad van België?",
                answers: ["Brussel", "Antwerpen", "Gent", "Luik"],
                correctIndex: 0
            ),
            QuizQuestion(
                id: "2",
                text: "Hoeveel planeten zijn er in ons zonnestelsel?",
                answers: ["7", "8", "9", "10"],
                correctIndex: 1
            ),
            QuizQuestion(
                id: "3",
                text: "Wie schilderde de Mona Lisa?",
                answers: ["Van Gogh", "Picasso", "Da Vinci", "Rembrandt"],
                correctIndex: 2
            ),
            QuizQuestion(
                id: "4",
                text: "In welk jaar begon de Eerste Wereldoorlog?",
                answers: ["1912", "1914", "1916", "1918"],
                correctIndex: 1
            ),
            QuizQuestion(
                id: "5",
                text: "Wat is de grootste oceaan ter wereld?",
                answers: ["Atlantische", "Indische", "Stille", "Arctische"],
                correctIndex: 2
            )
        ]
        print("✅ Fallback questions geladen: \(questions.count)")
    }

    private func resetForNewQuestion() {
        locked = false
        selectedIndex = nil
        isEndingRound = false
        timeLeft = 30
        answeredCount = 0
    }

    // MARK: - Answers listener
    private func startAnswersListener(questionIndex: Int) {
        answersCountListener?.remove()
        answeredCount = 0

        answersCountListener = fs.listenAnswersCount(roomId: roomId, questionIndex: questionIndex) { [weak self] count in
            guard let self else { return }
            Task { @MainActor in
                self.answeredCount = count
                self.checkAutoProgressIfHost()
            }
        }
    }

    // MARK: - Timer
    private func startTickTimer() {
        if tickCancellable != nil { return } // already ticking

        tickCancellable = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTimeLeft()
            }
    }

    private func updateTimeLeft() {
        guard status == "inGame" else { return }
        guard let started = questionStartedAt else { return }

        let elapsed = Int(Date().timeIntervalSince1970 - started)
        let remaining = max(0, 30 - elapsed)
        timeLeft = remaining

        if timeLeft == 0 {
            checkAutoProgressIfHost()
        }
    }

    private func syncLocalLockState() {
        if status == "inGame" { return }
        if status == "reveal" || status == "finished" {
            locked = true
        }
    }

    // MARK: - Submit answer
    func submit(answerIndex: Int) async {
        guard status == "inGame" else { return }
        guard !locked else { return }

        locked = true
        selectedIndex = answerIndex

        do {
            try await fs.submitAnswer(
                roomId: roomId,
                questionIndex: currentIndex,
                playerId: myUid,
                answerIndex: answerIndex
            )
            checkAutoProgressIfHost()
        } catch {
            print("Submit answer error:", error)
        }
    }

    // MARK: - Host auto-progress logic
    private func checkAutoProgressIfHost() {
        guard isHost else { return }
        guard status == "inGame" else { return }
        guard !isEndingRound else { return }

        let everyoneAnswered = (playersCount > 0) && (answeredCount >= playersCount)
        let timeUp = (timeLeft == 0)

        if everyoneAnswered || timeUp {
            isEndingRound = true
            Task { await endRoundRevealThenNext() }
        }
    }

    private func endRoundRevealThenNext() async {
        guard isHost else { return }
        defer { isEndingRound = false }

        // If out of range -> finish
        guard currentIndex < questions.count else {
            try? await fs.setRoomStatus(roomId: roomId, status: "finished")
            return
        }

        let correct = questions[currentIndex].correctIndex

        do {
            // 1) Reveal
            try await fs.setRoomStatus(roomId: roomId, status: "reveal")

            // 2) Score once (host-only)
            try await fs.scoreCurrentQuestionIfNeeded(
                roomId: roomId,
                questionIndex: currentIndex,
                correctIndex: correct
            )

            // 3) Wait so reveal is visible
            try await Task.sleep(nanoseconds: 3_000_000_000)

            // 4) Next / finish
            let next = currentIndex + 1
            let finished = next >= questions.count
            try await fs.advanceToNextQuestion(roomId: roomId, nextIndex: next, finished: finished)

        } catch {
            print("End round error:", error)
        }
    }
}
