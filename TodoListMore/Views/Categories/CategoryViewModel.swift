//
//  CategoryViewModel.swift
//  TodoListMore
//
//  Created by Harjot Singh on 28/03/25.
//

import Foundation
import CoreData
import SwiftUI
import Combine

/// ViewModel that manages categories and their updates
class CategoryViewModel: ObservableObject {
    // CoreData context
    private let context: NSManagedObjectContext
    private let dataController: DataController
    
    // Published properties that will trigger view updates
    @Published var categories: [Category] = []
    @Published var isLoading: Bool = false
    @Published var searchText: String = ""
    
    // Hold our cancellables
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext, dataController: DataController) {
        self.context = context
        self.dataController = dataController
        
        // Setup search text debounce
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadCategories()
            }
            .store(in: &cancellables)
        
        // Listen for data changes
        NotificationCenter.default.publisher(for: .dataDidChange)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadCategories()
            }
            .store(in: &cancellables)
    }
    
    /// Load all categories
    func loadCategories() {
        isLoading = true
        
        let fetchRequest = Category.fetchRequest()
        
        // Apply search filter if needed
        if !searchText.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", searchText)
        }
        
        // Sort categories by name
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            let fetchedCategories = try context.fetch(fetchRequest)
            DispatchQueue.main.async { [weak self] in
                // Don't use animation here - we'll handle it in the view instead
                self?.categories = fetchedCategories
                self?.isLoading = false
            }
        } catch {
            print("Error fetching categories: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
            }
        }
    }
    
    /// Add a new category
    func addCategory(name: String, colorHex: String) -> Bool {
        guard !name.isEmpty else { return false }
        
        if let _ = dataController.addCategory(name: name, colorHex: colorHex) {
            // DataController.addCategory will post notifications which we're already
            // observing in the initializer
            return true
        }
        return false
    }
    
    /// Update an existing category
    func updateCategory(id: UUID, name: String?, colorHex: String?) -> Bool {
        guard id != UUID() else { return false }
        
        if dataController.updateCategory(id: id, name: name, colorHex: colorHex) {
            // We don't need to do anything here, as the DataController is already
            // posting the correct notifications, and we're listening for .dataDidChange
            // in this class's initializer
            return true
        }
        return false
    }
    
    /// Delete a category
    func deleteCategory(_ category: Category) {
        // DataController.delete will already post the dataDidChange notification
        // which we're observing in the initializer
        dataController.delete(category)
        // No need to call loadCategories() as we're already listening for changes
    }
    
    /// Get the count of tasks for a category
    func taskCount(for category: Category) -> Int {
        return category.categoryTasks.count
    }
}

// Add a specific notification for category updates
extension Notification.Name {
    static let categoryUpdated = Notification.Name("categoryUpdated")
}