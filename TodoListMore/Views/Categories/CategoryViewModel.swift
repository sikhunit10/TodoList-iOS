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

/// A simple, direct model for category information in UI
struct CategoryUIModel: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let colorHex: String
    let taskCount: Int
    
    static func == (lhs: CategoryUIModel, rhs: CategoryUIModel) -> Bool {
        return lhs.id == rhs.id && 
               lhs.name == rhs.name && 
               lhs.colorHex == rhs.colorHex &&
               lhs.taskCount == rhs.taskCount
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(colorHex)
        hasher.combine(taskCount)
    }
    
    // Create from Core Data Category entity
    init(from category: Category, taskCount: Int) {
        self.id = category.id ?? UUID()
        self.name = category.safeName
        self.colorHex = category.safeColorHex
        self.taskCount = taskCount
    }
}

/// ViewModel that manages categories and their updates
class CategoryViewModel: ObservableObject {
    // CoreData context
    private let context: NSManagedObjectContext
    private let dataController: DataController
    
    // Published properties that will trigger view updates - using our UI model
    @Published var categoryModels: [CategoryUIModel] = []
    @Published var isLoading: Bool = true
    @Published var searchText: String = ""
    
    // Hold our cancellables
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext, dataController: DataController) {
        self.context = context
        self.dataController = dataController
        
        // Setup search text debounce
        $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
        
        // Setup notification listeners - more specific listeners
        NotificationCenter.default.publisher(for: .categoriesDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                // Selective update based on category ID
                if let categoryId = notification.userInfo?["categoryId"] as? UUID,
                   let index = self?.categoryModels.firstIndex(where: { $0.id == categoryId }) {
                    // Update just this category
                    self?.refreshCategory(id: categoryId)
                } else {
                    // Full refresh if needed
                    self?.refreshData()
                }
            }
            .store(in: &cancellables)
            
        // Backup listener for general data changes
        NotificationCenter.default.publisher(for: .dataDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
        
        // Initial data load
        refreshData()
    }
    
    // MARK: - Data Refreshing
    
    /// Force refresh the data
    func forceRefresh() {
        refreshData()
    }
    
    /// Refresh a specific category by ID
    func refreshCategory(id: UUID) {
        // Use the main context for single category refresh - more efficient
        // No need to set isLoading for single category updates
        
        let fetchRequest = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            // Fetch just this category
            let categories = try context.fetch(fetchRequest)
            if let category = categories.first {
                let taskCount = (category.tasks?.count ?? 0)
                let updatedModel = CategoryUIModel(
                    from: category,
                    taskCount: taskCount
                )
                
                // Find and update the existing model
                if let index = categoryModels.firstIndex(where: { $0.id == id }) {
                    categoryModels[index] = updatedModel
                }
            }
        } catch {
            print("Error refreshing category: \(error)")
        }
    }
    
    /// Refresh all data from Core Data and update UI models
    func refreshData() {
        isLoading = true
        
        // Get a shared background context instead of creating a new one each time
        let backgroundContext = dataController.container.viewContext
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            let fetchRequest = Category.fetchRequest()
            
            // Apply search filter if needed
            if !self.searchText.isEmpty {
                fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", self.searchText)
            }
            
            // Sort categories by name
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            
            do {
                // Fetch categories
                let categories = try backgroundContext.fetch(fetchRequest)
                
                // Convert to UI models
                let uiModels = categories.map { category in
                    let taskCount = (category.tasks?.count ?? 0)
                    return CategoryUIModel(from: category, taskCount: taskCount)
                }
                
                // Update on main thread
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.categoryModels = uiModels
                }
            } catch {
                print("Error fetching categories: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Add a new category
    func addCategory(name: String, colorHex: String) -> Bool {
        guard !name.isEmpty else { return false }
        
        if let _ = dataController.addCategory(name: name, colorHex: colorHex) {
            refreshData()
            return true
        }
        return false
    }
    
    /// Update an existing category
    func updateCategory(id: UUID, name: String?, colorHex: String?) -> Bool {
        guard id != UUID() else { return false }
        
        // Optimistic UI update for better responsiveness
        if let name = name, let colorHex = colorHex {
            updateUIModelDirectly(id: id, name: name, colorHex: colorHex)
        }
        
        // Perform the actual update (with notification that will trigger refresh)
        let result = dataController.updateCategory(id: id, name: name, colorHex: colorHex)
        
        // No need for manual refresh - will be handled by notification system
        return result
    }
    
    /// Direct UI update without waiting for Core Data
    private func updateUIModelDirectly(id: UUID, name: String, colorHex: String) {
        DispatchQueue.main.async {
            if let index = self.categoryModels.firstIndex(where: { $0.id == id }) {
                let oldModel = self.categoryModels[index]
                let updatedModel = CategoryUIModel(
                    id: id, name: name, colorHex: colorHex, taskCount: oldModel.taskCount
                )
                self.categoryModels[index] = updatedModel
            }
        }
    }
    
    /// Delete a category
    func deleteCategory(id: UUID) {
        let request = Category.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let category = try context.fetch(request).first {
                dataController.delete(category)
                refreshData()
            }
        } catch {
            print("Error finding category to delete: \(error)")
        }
    }
    
    /// Get the count of tasks for a category
    func taskCount(for category: Category) -> Int {
        return category.tasks?.count ?? 0
    }
}

// Helper extension for creating CategoryUIModel directly
extension CategoryUIModel {
    init(id: UUID, name: String, colorHex: String, taskCount: Int) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.taskCount = taskCount
    }
}

// Add a specific notification for category updates
extension Notification.Name {
    static let categoryUpdated = Notification.Name("categoryUpdated")
}