import Foundation

struct QuizQuestion: Codable, Identifiable {
    let id: String
    let text: String
    let answers: [String]
    let correctIndex: Int
}
