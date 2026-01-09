import Foundation
import CoreData
import Combine

struct OfflineRow: Identifiable, Hashable {
    let id = UUID()
    let question: String
    let savedAt: Date
}

@MainActor
final class OfflineQuestionsViewModel: ObservableObject {

    @Published var rows: [OfflineRow] = []
    @Published var lastUpdatedText: String = "—"
    @Published var errorMessage: String? = nil
    @Published var isOffline: Bool = false
    @Published var isLoading: Bool = false

    // MOET exact matchen met je .xcdatamodeld entity naam
    private let entityName = "CachedQuestion"

    // MARK: - Load
    func loadFromCache(context: NSManagedObjectContext?) {
        errorMessage = nil
        isOffline = false

        guard let context else {
            rows = []
            lastUpdatedText = "—"
            errorMessage = "Geen Core Data context gevonden."
            return
        }

        guard NSEntityDescription.entity(forEntityName: entityName, in: context) != nil else {
            rows = []
            lastUpdatedText = "—"
            errorMessage = "Core Data entity '\(entityName)' bestaat niet. Controleer je .xcdatamodeld."
            return
        }

        let req = NSFetchRequest<NSManagedObject>(entityName: entityName)
        req.sortDescriptors = [NSSortDescriptor(key: "savedAt", ascending: false)]
        req.fetchLimit = 200

        do {
            let result = try context.fetch(req)
            let mapped: [OfflineRow] = result.map { obj in
                let q = (obj.value(forKey: "questionText") as? String) ?? "(geen tekst)"
                let d = (obj.value(forKey: "savedAt") as? Date) ?? .distantPast
                return OfflineRow(question: q, savedAt: d)
            }

            rows = mapped
            isOffline = !mapped.isEmpty

            if let newest = mapped.first?.savedAt, newest != .distantPast {
                lastUpdatedText = Self.format(date: newest)
            } else {
                lastUpdatedText = "—"
            }
        } catch {
            rows = []
            lastUpdatedText = "—"
            errorMessage = "Fout bij laden uit Core Data: \(error.localizedDescription)"
        }
    }

    // MARK: - Refresh from web
    func refreshFromWeb(context: NSManagedObjectContext?, amount: Int) async {
        guard let context else {
            errorMessage = "Geen Core Data context gevonden."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Clear oude cache eerst
            clearCache(context: context)

            // TODO: Vervang dit met je echte API call naar je backend
            // Bijvoorbeeld: let questions = try await FirestoreService().fetchQuestions(amount: amount)
            
            // Voor nu: dummy data als placeholder
            let dummyQuestions = [
                "Wat is de hoofdstad van België?",
                "Hoeveel planeten zijn er in ons zonnestelsel?",
                "Wie schilderde de Mona Lisa?",
                "In welk jaar begon de Eerste Wereldoorlog?",
                "Wat is de grootste oceaan ter wereld?",
                "Hoeveel continenten zijn er?",
                "Wat is de chemische formule voor water?",
                "Wie schreef Romeo en Julia?",
                "Wat is de snelheid van licht?",
                "In welk jaar landde de mens op de maan?"
            ]

            // Sla op in Core Data
            guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
                errorMessage = "Entity '\(entityName)' niet gevonden in Core Data model."
                return
            }

            for question in dummyQuestions.prefix(amount) {
                let obj = NSManagedObject(entity: entity, insertInto: context)
                obj.setValue(question, forKey: "questionText")
                obj.setValue(Date(), forKey: "savedAt")
            }

            try context.save()

            // Reload from cache
            loadFromCache(context: context)

        } catch {
            errorMessage = "Fout bij ophalen vragen: \(error.localizedDescription)"
        }
    }

    // MARK: - Clear
    func clearCache(context: NSManagedObjectContext?) {
        errorMessage = nil
        guard let context else { return }

        guard NSEntityDescription.entity(forEntityName: entityName, in: context) != nil else {
            errorMessage = "Entity '\(entityName)' bestaat niet in je model."
            return
        }

        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let delete = NSBatchDeleteRequest(fetchRequest: fetch)

        do {
            try context.execute(delete)
            try context.save()
            rows = []
            lastUpdatedText = "—"
            isOffline = false
        } catch {
            errorMessage = "Fout bij verwijderen cache: \(error.localizedDescription)"
        }
    }

    private static func format(date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_BE")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
