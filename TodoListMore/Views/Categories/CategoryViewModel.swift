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
    @Published var isLoading: Bool = true
    @Published var searchText: String = ""
    
    // Hold our cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Timer for auto-refresh
    private var autoRefreshTimer: Timer?
    
    init(context: NSManagedObjectContext, dataController: DataController) {
        self.context = context
        self.dataController = dataController
        
        // Setup search text debounce
        $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.forceRefresh()
            }
            .store(in: &cancellables)
        
        // Listen for various data change notifications
        setupNotificationListeners()
        
        // Start auto-refresh timer
        startAutoRefreshTimer()
        
        // Initial data load
        DispatchQueue.main.async {
            self.forceRefresh()
        }
    }
    
    deinit {
        // Stop timer when this view model is deinitialized
        stopAutoRefreshTimer()
    }
    
    // MARK: - Notification Handling
    
    private func setupNotificationListeners() {
        // Core Data changes
        NotificationCenter.default.publisher(for: .dataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.forceRefresh()
            }
            .store(in: &cancellables)
        
        // Specific category updates
        NotificationCenter.default.publisher(for: .categoryUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.forceRefresh()
            }
            .store(in: &cancellables)
        
        // NSManagedObjectContextDidSave notification
        NotificationCenter.default.publisher(for: NSManagedObjectContext.didSaveObjectIDsNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.context.refreshAllObjects()
                self?.forceRefresh()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Timer Management
    
    private func startAutoRefreshTimer() {
        stopAutoRefreshTimer() // Ensure we don't have multiple timers
        
        // Create a timer that fires every 2 seconds to ensure UI stays updated
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.forceRefresh()
        }
    }
    
    private func stopAutoRefreshTimer() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }
    
    // MARK: - Data Refreshing
    
    func forceRefresh() {
        isLoading = categories.isEmpty
        loadCategories(forceUpdate: true)
    }
    
    /// Load all categories with aggressive refresh
    func loadCategories(forceUpdate: Bool = false) {
        // Create a new fetch request to get fresh data
        let fetchRequest = Category.fetchRequest()
        
        // Apply search filter if needed
        if !searchText.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", searchText)
        }
        
        // Sort categories by name
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        // Ensure we have the latest data
        context.refreshAllObjects()
        
        do {
            // Fetch categories
            let fetchedCategories = try context.fetch(fetchRequest)
            
            // Update on the main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Always update the categories array
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.categories = fetchedCategories
                    self.isLoading = false
                }
                
                // Force refresh views
                self.objectWillChange.send()
            }
        } catch {
            print("Error fetching categories: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
            }
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Add a new category
    func addCategory(name: String, colorHex: String) -> Bool {
        guard !name.isEmpty else { return false }
        
        // Use main context for immediate UI update
        if let _ = dataController.addCategory(name: name, colorHex: colorHex) {
            // Force immediate UI update
            DispatchQueue.main.async {
                // Ensure context is up-to-date
                self.context.refreshAllObjects()
                
                // Force a reload
                self.forceRefresh()
                
                // Post notification for any other interested observers
                NotificationCenter.default.post(name: .dataDidChange, object: nil)
            }
            return true
        }
        return false
    }
    
    /// Update an existing category - direct update for immediate response
    func updateCategory(id: UUID, name: String?, colorHex: String?) -> Bool {
        guard id != UUID() else { return false }
        
        let result = dataController.updateCategory(id: id, name: name, colorHex: colorHex)
        
        // Force multiple refreshes to ensure UI updates properly
        if result {
            // Immediate refresh
            DispatchQueue.main.async { [weak self] in
                self?.context.refreshAllObjects()
                self?.forceRefresh()
            }
            
            // Delayed refresh to catch any pending changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.context.refreshAllObjects()
                self?.forceRefresh()
            }
        }
        
        return result
    }
    
    /// Delete a category with immediate update
    func deleteCategory(_ category: Category) {
        // Delete using data controller
        dataController.delete(category)
        
        // Ensure immediate UI update
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Ensure the context is refreshed
            self.context.refreshAllObjects()
            
            // Force refresh
            self.forceRefresh()
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