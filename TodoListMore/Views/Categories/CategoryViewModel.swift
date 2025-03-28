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
    
    // Track if we're currently updating to prevent visual flashes
    private var isUpdating = false
    
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
        // We'll set a short timeout to reset the isUpdating flag in case something goes wrong
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.isUpdating = false
        }
        
        // Set loading state based on whether we have data already
        isLoading = categories.isEmpty
        isUpdating = true
        
        let fetchRequest = Category.fetchRequest()
        
        // Apply search filter if needed
        if !searchText.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", searchText)
        }
        
        // Sort categories by name
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            // Always fetch the latest categories
            let fetchedCategories = try context.fetch(fetchRequest)
            
            // Always update on the main thread
            DispatchQueue.main.async { [weak self] in
                // Cancel the timeout timer since we completed normally
                timeoutTimer.invalidate()
                
                // Always update the categories to ensure changes are reflected
                self?.categories = fetchedCategories
                self?.isLoading = false
                self?.isUpdating = false
                
                // Force UI update
                self?.objectWillChange.send()
            }
        } catch {
            print("Error fetching categories: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                // Cancel the timeout timer
                timeoutTimer.invalidate()
                
                self?.isLoading = false
                self?.isUpdating = false
            }
        }
    }
    
    /// Add a new category
    func addCategory(name: String, colorHex: String) -> Bool {
        guard !name.isEmpty else { return false }
        
        if let _ = dataController.addCategory(name: name, colorHex: colorHex) {
            // Force a reload to update the list
            DispatchQueue.main.async {
                self.loadCategories()
            }
            return true
        }
        return false
    }
    
    /// Update an existing category
    func updateCategory(id: UUID, name: String?, colorHex: String?) -> Bool {
        guard id != UUID() else { return false }
        
        if dataController.updateCategory(id: id, name: name, colorHex: colorHex) {
            // Force a reload to update the list
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.loadCategories()
            }
            return true
        }
        return false
    }
    
    /// Delete a category
    func deleteCategory(_ category: Category) {
        dataController.delete(category)
        
        // Force a reload to update the list
        DispatchQueue.main.async {
            self.loadCategories()
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