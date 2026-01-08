import Foundation
import UIKit

final class TriviaAPIService {

    func fetchQuestions(amount: Int) async throws -> [QuizQuestion] {
        let urlString = "https://opentdb.com/api.php?amount=\(amount)&type=multiple"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(TriviaResponse.self, from: data)

        return decoded.results.map { q in
            let answers = (q.incorrect_answers + [q.correct_answer]).shuffled()
            let correctIndex = answers.firstIndex(of: q.correct_answer) ?? 0

            return QuizQuestion(
                id: UUID().uuidString,
                text: q.question.htmlDecoded,
                answers: answers.map { $0.htmlDecoded },
                correctIndex: correctIndex
            )
        }
    }
}

// MARK: - API Models
private struct TriviaResponse: Codable {
    let results: [TriviaQuestionDTO]
}

private struct TriviaQuestionDTO: Codable {
    let question: String
    let correct_answer: String
    let incorrect_answers: [String]
}

// MARK: - HTML decode helper
private extension String {
    var htmlDecoded: String {
        guard let data = self.data(using: .utf8) else { return self }
        do {
            let attributed = try NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
            return attributed.string
        } catch {
            return self
        }
    }
}
