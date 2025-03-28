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
                // Wrap the update in a withAnimation block to ensure smooth transitions
                withAnimation(.smooth) {
                    self?.categories = fetchedCategories
                    self?.isLoading = false
                }
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
            // Force UI update
            self.objectWillChange.send()
            loadCategories()
            return true
        }
        return false
    }
    
    /// Update an existing category
    func updateCategory(id: UUID, name: String?, colorHex: String?) -> Bool {
        guard id != UUID() else { return false }
        
        if dataController.updateCategory(id: id, name: name, colorHex: colorHex) {
            // Immediately force a UI update
            DispatchQueue.main.async {
                // Force UI update
                self.objectWillChange.send()
                
                // Explicitly refresh the context to get the latest data
                self.context.refreshAllObjects()
                
                // Force reload categories with animation
                self.loadCategories()
                
                // Notify listeners of the specific category ID that was updated
                NotificationCenter.default.post(
                    name: .categoryUpdated,
                    object: nil,
                    userInfo: ["categoryId": id]
                )
                
                // Also post general data change notification
                NotificationCenter.default.post(name: .dataDidChange, object: nil)
            }
            
            return true
        }
        return false
    }
    
    /// Delete a category
    func deleteCategory(_ category: Category) {
        withAnimation(.smooth) {
            dataController.delete(category)
            loadCategories()
        }
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