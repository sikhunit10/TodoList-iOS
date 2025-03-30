//
//  TodoListMoreApp.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import CoreData

@main
struct TodoListMoreApp: App {
    // Inject our CoreData controller into the SwiftUI environment
    @StateObject private var dataController = DataController.shared
    
    init() {
        // Since we can't effectively change the appearance of SearchBar across different views,
        // we'll leave it at the default values and let SwiftUI handle it naturally
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .environmentObject(dataController)
        }
    }
}