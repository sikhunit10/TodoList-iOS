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
    /// Emoji or icon for quick visual scanning
    let icon: String
    /// Optional description or notes about the category
    let note: String
    
    static func == (lhs: CategoryUIModel, rhs: CategoryUIModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.colorHex == rhs.colorHex &&
               lhs.taskCount == rhs.taskCount &&
               lhs.icon == rhs.icon &&
               lhs.note == rhs.note
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(colorHex)
        hasher.combine(taskCount)
        hasher.combine(icon)
        hasher.combine(note)
    }
    
    // Create from Core Data Category entity
    init(from category: Category, taskCount: Int) {
        self.id = category.id ?? UUID()
        self.name = category.safeName
        self.colorHex = category.safeColorHex
        self.taskCount = taskCount
        self.icon = category.safeIcon
        self.note = category.safeNote
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
        // Indicate loading state
        isLoading = true

        // Prepare fetch request for Category entities
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        if !searchText.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", searchText)
        }
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        do {
            // Perform synchronous fetch on main context
            let categories = try context.fetch(fetchRequest)
            // Map to UI models
            let uiModels = categories.map { category in
                let taskCount = category.tasks?.count ?? 0
                return CategoryUIModel(from: category, taskCount: taskCount)
            }
            // Update published properties
            isLoading = false
            categoryModels = uiModels
        } catch {
            print("Error fetching categories: \(error)")
            isLoading = false
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Add a new category with optional icon and note
    func addCategory(name: String,
                     colorHex: String,
                     icon: String? = nil,
                     note: String? = nil) -> Bool {
        guard !name.isEmpty else { return false }

        if let _ = dataController.addCategory(name: name,
                                              colorHex: colorHex,
                                              icon: icon,
                                              note: note) {
            refreshData()
            return true
        }
        return false
    }
    
    /// Update an existing category: name, color, icon, and/or note
    func updateCategory(id: UUID,
                        name: String? = nil,
                        colorHex: String? = nil,
                        icon: String? = nil,
                        note: String? = nil) -> Bool {
        guard id != UUID() else { return false }

        // Optimistic UI update for name and color; icon/note refresh via data reload
        if let index = categoryModels.firstIndex(where: { $0.id == id }) {
            let old = categoryModels[index]
            let updatedName = name ?? old.name
            let updatedColor = colorHex ?? old.colorHex
            // Keep existing icon and note until reload
            updateUIModelDirectly(id: id,
                                  name: updatedName,
                                  colorHex: updatedColor,
                                  icon: old.icon,
                                  note: old.note)
        }

        // Perform the actual update
        let result = dataController.updateCategory(id: id,
                                                  name: name,
                                                  colorHex: colorHex,
                                                  icon: icon,
                                                  note: note)
        return result
    }
    
    /// Direct UI update without waiting for Core Data
    private func updateUIModelDirectly(id: UUID,
                                       name: String,
                                       colorHex: String,
                                       icon: String,
                                       note: String) {
        DispatchQueue.main.async {
            if let index = self.categoryModels.firstIndex(where: { $0.id == id }) {
                let oldModel = self.categoryModels[index]
                let updatedModel = CategoryUIModel(
                    id: id,
                    name: name,
                    colorHex: colorHex,
                    taskCount: oldModel.taskCount,
                    icon: icon,
                    note: note
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
    /// Initialize directly with all UI properties; icon and note default to empty
    init(id: UUID,
         name: String,
         colorHex: String,
         taskCount: Int,
         icon: String = "",
         note: String = "") {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.taskCount = taskCount
        self.icon = icon
        self.note = note
    }
}

// Add a specific notification for category updates
extension Notification.Name {
    static let categoryUpdated = Notification.Name("categoryUpdated")
}