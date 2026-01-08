import Foundation
import CoreData

final class CacheService {
    static let shared = CacheService()

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    // MARK: - Save podium/final scores
    func saveFinalScores(roomCode: String, scores: [(name: String, score: Int)]) {
        // Optional: clear existing cached scores for this room
        deleteScores(roomCode: roomCode)

        for s in scores {
            let obj = NSEntityDescription.insertNewObject(forEntityName: "CachedScore", into: context)
            obj.setValue(roomCode, forKey: "roomCode")
            obj.setValue(s.name, forKey: "playerName")
            obj.setValue(Int16(s.score), forKey: "score")
            obj.setValue(Date(), forKey: "finishedAt")
        }

        do {
            try context.save()
        } catch {
            print("CoreData saveFinalScores error:", error)
        }
    }

    // MARK: - Fetch podium/final scores
    func fetchFinalScores(roomCode: String) -> [(name: String, score: Int)] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CachedScore")
        request.predicate = NSPredicate(format: "roomCode == %@", roomCode)
        request.sortDescriptors = [
            NSSortDescriptor(key: "score", ascending: false),
            NSSortDescriptor(key: "finishedAt", ascending: false)
        ]

        do {
            let results = try context.fetch(request)
            return results.compactMap { obj in
                let name = obj.value(forKey: "playerName") as? String ?? "?"
                let score16 = obj.value(forKey: "score") as? Int16 ?? 0
                return (name: name, score: Int(score16))
            }
        } catch {
            print("CoreData fetchFinalScores error:", error)
            return []
        }
    }

    // MARK: - Helpers
    private func deleteScores(roomCode: String) {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CachedScore")
        request.predicate = NSPredicate(format: "roomCode == %@", roomCode)

        do {
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("CoreData deleteScores error:", error)
        }
    }
}
