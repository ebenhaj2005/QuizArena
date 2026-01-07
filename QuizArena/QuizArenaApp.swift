//
//  QuizArenaApp.swift
//  QuizArena
//
//  Created by Bilal Masungi on 07/01/2026.
//

import SwiftUI
import CoreData

@main
struct QuizArenaApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
