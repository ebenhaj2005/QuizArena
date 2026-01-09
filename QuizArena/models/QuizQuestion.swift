import Foundation

struct QuizQuestion: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let answers: [String]
    let correctIndex: Int
}
