import Foundation
import CoreData

final class CacheService {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Save
    func saveQuestions(_ questions: [QuizQuestion]) throws {
        // Clear previous cache
        let fetch: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CachedQuestion")
        let delete = NSBatchDeleteRequest(fetchRequest: fetch)
        try context.execute(delete)

        // Insert new
        for q in questions {
            let obj = NSEntityDescription.insertNewObject(forEntityName: "CachedQuestion", into: context)
            obj.setValue(q.id, forKey: "id")
            obj.setValue(q.text, forKey: "text")
            obj.setValue(Int16(q.correctIndex), forKey: "correctIndex")
            obj.setValue(q.answers.joined(separator: "|||"), forKey: "answers")
            obj.setValue(Date(), forKey: "updatedAt")
        }

        // Update meta
        let meta = try fetchOrCreateMeta()
        meta.setValue(Date(), forKey: "lastUpdated")
        meta.setValue(Int16(questions.count), forKey: "questionCount")

        try context.save()
    }

    // MARK: - Load
    func loadQuestions() throws -> [QuizQuestion] {
        let req = NSFetchRequest<NSManagedObject>(entityName: "CachedQuestion")
        req.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

        let rows = try context.fetch(req)
        return rows.compactMap { row in
            guard
                let id = row.value(forKey: "id") as? String,
                let text = row.value(forKey: "text") as? String,
                let answersStr = row.value(forKey: "answers") as? String
            else { return nil }

            let answers = answersStr.components(separatedBy: "|||")
            let correct = Int(row.value(forKey: "correctIndex") as? Int16 ?? 0)

            return QuizQuestion(id: id, text: text, answers: answers, correctIndex: correct)
        }
    }

    // MARK: - Meta
    func lastUpdated() throws -> Date? {
        let meta = try fetchOrCreateMeta()
        return meta.value(forKey: "lastUpdated") as? Date
    }

    private func fetchOrCreateMeta() throws -> NSManagedObject {
        let req = NSFetchRequest<NSManagedObject>(entityName: "AppMeta")
        req.predicate = NSPredicate(format: "id == %@", "meta")
        req.fetchLimit = 1

        if let existing = try context.fetch(req).first {
            return existing
        }

        let obj = NSEntityDescription.insertNewObject(forEntityName: "AppMeta", into: context)
        obj.setValue("meta", forKey: "id")
        obj.setValue(nil, forKey: "lastUpdated")
        obj.setValue(Int16(0), forKey: "questionCount")
        return obj
    }
}
