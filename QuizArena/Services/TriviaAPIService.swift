import Foundation
import CoreData
import UIKit

@MainActor
final class TriviaAPIService {

    // MARK: - Core Data entity names
    private let cachedEntity = "CachedQuestion"   // questionText:String, savedAt:Date
    private let metaEntity   = "LocalMatch"       // key:String, updatedAt:Date

    // MARK: - Public API

    /// Fetch questions from OpenTDB + cache them for offline use
    func fetchQuestions(
        amount: Int,
        context: NSManagedObjectContext?
    ) async throws -> [QuizQuestion] {

        let urlString = "https://opentdb.com/api.php?amount=\(amount)&type=multiple"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(TriviaResponse.self, from: data)

        let questions: [QuizQuestion] = decoded.results.map { q in
            let answers = (q.incorrect_answers + [q.correct_answer]).shuffled()
            let correctIndex = answers.firstIndex(of: q.correct_answer) ?? 0

            return QuizQuestion(
                id: UUID().uuidString,
                text: q.question.htmlDecoded,
                answers: answers.map { $0.htmlDecoded },
                correctIndex: correctIndex
            )
        }

        // Cache plain text questions
        if let context {
            cacheQuestionsText(questions.map { $0.text }, context: context)
            updateLastUpdatedMeta(date: Date(), context: context)
        }

        return questions
    }

    /// Load cached questions (offline fallback)
    func loadCachedQuestions(context: NSManagedObjectContext?) -> [OfflineRow] {
        guard let context else { return [] }
        guard entityExists(cachedEntity, in: context) else { return [] }

        let req = NSFetchRequest<NSManagedObject>(entityName: cachedEntity)
        req.sortDescriptors = [NSSortDescriptor(key: "savedAt", ascending: false)]

        do {
            let result = try context.fetch(req)
            return result.map {
                OfflineRow(
                    question: $0.value(forKey: "questionText") as? String ?? "(geen tekst)",
                    savedAt: $0.value(forKey: "savedAt") as? Date ?? .distantPast
                )
            }
        } catch {
            print("❌ loadCachedQuestions error:", error)
            return []
        }
    }

    /// Load last updated date
    func loadLastUpdated(context: NSManagedObjectContext?) -> Date? {
        guard let context else { return nil }
        guard entityExists(metaEntity, in: context) else { return nil }

        let req = NSFetchRequest<NSManagedObject>(entityName: metaEntity)
        req.predicate = NSPredicate(format: "key == %@", "lastUpdated")
        req.fetchLimit = 1

        return try? context.fetch(req).first?.value(forKey: "updatedAt") as? Date
    }

    // MARK: - Core Data caching

    private func cacheQuestionsText(
        _ questions: [String],
        context: NSManagedObjectContext
    ) {
        guard entityExists(cachedEntity, in: context) else { return }
        guard hasAttribute("questionText", in: cachedEntity, context: context),
              hasAttribute("savedAt", in: cachedEntity, context: context) else { return }

        // Clear old cache
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: cachedEntity)
        let delete = NSBatchDeleteRequest(fetchRequest: fetch)
        _ = try? context.execute(delete)

        let now = Date()
        for q in questions {
            let obj = NSEntityDescription.insertNewObject(
                forEntityName: cachedEntity,
                into: context
            )
            obj.setValue(q, forKey: "questionText")
            obj.setValue(now, forKey: "savedAt")
        }

        try? context.save()
    }

    private func updateLastUpdatedMeta(
        date: Date,
        context: NSManagedObjectContext
    ) {
        guard entityExists(metaEntity, in: context) else { return }
        guard hasAttribute("key", in: metaEntity, context: context),
              hasAttribute("updatedAt", in: metaEntity, context: context) else { return }

        let req = NSFetchRequest<NSManagedObject>(entityName: metaEntity)
        req.predicate = NSPredicate(format: "key == %@", "lastUpdated")
        req.fetchLimit = 1

        do {
            if let existing = try context.fetch(req).first {
                existing.setValue(date, forKey: "updatedAt")
            } else {
                let meta = NSEntityDescription.insertNewObject(
                    forEntityName: metaEntity,
                    into: context
                )
                meta.setValue("lastUpdated", forKey: "key")
                meta.setValue(date, forKey: "updatedAt")
            }
            try context.save()
        } catch {
            print("⚠️ Meta update failed:", error)
        }
    }

    // MARK: - Safety helpers

    private func entityExists(
        _ name: String,
        in context: NSManagedObjectContext
    ) -> Bool {
        NSEntityDescription.entity(forEntityName: name, in: context) != nil
    }

    private func hasAttribute(
        _ attr: String,
        in entity: String,
        context: NSManagedObjectContext
    ) -> Bool {
        NSEntityDescription
            .entity(forEntityName: entity, in: context)?
            .attributesByName[attr] != nil
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
        guard let data = data(using: .utf8) else { return self }
        let attr = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
        return attr?.string ?? self
    }
}
