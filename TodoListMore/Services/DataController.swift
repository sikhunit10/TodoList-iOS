//
//  DataController.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import CoreData
import SwiftUI

// Define a notification name for data changes
extension Notification.Name {
    static let dataDidChange = Notification.Name("dataDidChange")
}

class DataController: ObservableObject {
    static let shared = DataController()
    
    // CoreData container
    let container: NSPersistentContainer
    
    init() {
        // Initialize with regular NSPersistentContainer for local storage
        container = NSPersistentContainer(name: "TodoListMore")
        
        // Configure container for local storage
        container.loadPersistentStores { description, error in
            if let error = error {
                print("CoreData failed to load: \(error.localizedDescription)")
            }
        }
        
        // Enable automatic merging of changes
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - CRUD Operations
    
    // Save context if changes exist
    func save() {
        if container.viewContext.hasChanges {
            do {
                try container.viewContext.save()
                
                // After successful save, ensure all UI elements have the most current data
                objectWillChange.send()
                
                // Refresh all objects to ensure changes propagate to all views
                container.viewContext.refreshAllObjects()
                
                // Post a notification that data has changed
                NotificationCenter.default.post(name: .dataDidChange, object: nil)
                
                // Add a small delay to ensure UI can update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.objectWillChange.send()
                    // Post another notification after delay for views that may need to update later
                    NotificationCenter.default.post(name: .dataDidChange, object: nil)
                }
            } catch {
                print("Error saving context: \(error.localizedDescription)")
                // Just print the error since we removed the syncStatus
                print("Failed to save data: \(error.localizedDescription)")
            }
        }
    }
    
    // Delete objects
    func delete(_ object: NSManagedObject) {
        container.viewContext.delete(object)
        save()
    }
    
    // MARK: - Task Operations
    
    func addTask(title: String, description: String, dueDate: Date?, priority: Int16, categoryId: UUID? = nil) -> NSManagedObject? {
        let context = container.viewContext
        
        // Using string-based Key-Value Coding for safe access to entity
        let task = NSEntityDescription.insertNewObject(forEntityName: "Task", into: context)
            
        let now = Date()
        
        // Set values using KVC instead of direct property access
        task.setValue(UUID(), forKey: "id")
        task.setValue(title, forKey: "title")
        task.setValue(description, forKey: "taskDescription")
        task.setValue(dueDate, forKey: "dueDate")
        task.setValue(priority, forKey: "priority")
        task.setValue(false, forKey: "isCompleted")
        task.setValue(now, forKey: "dateCreated")
        task.setValue(now, forKey: "dateModified")
        
        // If we have a category ID, find that category and associate it
        if let categoryId = categoryId {
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Category")
            fetchRequest.predicate = NSPredicate(format: "id == %@", categoryId as CVarArg)
            
            do {
                let categories = try context.fetch(fetchRequest)
                if let category = categories.first {
                    task.setValue(category, forKey: "category")
                }
            } catch {
                print("Error fetching category: \(error.localizedDescription)")
            }
        }
        
        save()
        return task
    }
    
    func updateTask(id: UUID, title: String? = nil, description: String? = nil, 
                    dueDate: Date? = nil, removeDueDate: Bool = false,
                    priority: Int16? = nil, isCompleted: Bool? = nil, 
                    categoryId: UUID? = nil, removeCategoryId: Bool = false) -> Bool {
        
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Task")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let tasks = try context.fetch(fetchRequest)
            guard let task = tasks.first else { return false }
            
            // Update only provided fields
            if let title = title {
                task.setValue(title, forKey: "title")
            }
            
            if let description = description {
                task.setValue(description, forKey: "taskDescription")
            }
            
            if let dueDate = dueDate {
                task.setValue(dueDate, forKey: "dueDate")
            } else if removeDueDate {
                task.setValue(nil, forKey: "dueDate")
            }
            
            if let priority = priority {
                task.setValue(priority, forKey: "priority")
            }
            
            if let isCompleted = isCompleted {
                task.setValue(isCompleted, forKey: "isCompleted")
            }
            
            if let categoryId = categoryId {
                let categoryFetch: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Category")
                categoryFetch.predicate = NSPredicate(format: "id == %@", categoryId as CVarArg)
                
                let categories = try context.fetch(categoryFetch)
                if let category = categories.first {
                    task.setValue(category, forKey: "category")
                }
            } else if removeCategoryId {
                task.setValue(nil, forKey: "category")
            }
            
            task.setValue(Date(), forKey: "dateModified")
            
            save()
            return true
        } catch {
            print("Error updating task: \(error.localizedDescription)")
            return false
        }
    }
    
    func toggleTaskCompletion(id: UUID) -> Bool {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Task")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let tasks = try context.fetch(fetchRequest)
            if let task = tasks.first {
                let currentValue = task.value(forKey: "isCompleted") as? Bool ?? false
                task.setValue(!currentValue, forKey: "isCompleted")
                task.setValue(Date(), forKey: "dateModified")
                
                save()
                return true
            } else {
                return false
            }
        } catch {
            print("Error toggling task completion: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Category Operations
    
    func addCategory(name: String, colorHex: String) -> NSManagedObject? {
        let context = container.viewContext
        
        let category = NSEntityDescription.insertNewObject(forEntityName: "Category", into: context)
        
        category.setValue(UUID(), forKey: "id")
        category.setValue(name, forKey: "name")
        category.setValue(colorHex, forKey: "colorHex")
        
        save()
        return category
    }
    
    func updateCategory(id: UUID, name: String? = nil, colorHex: String? = nil) -> Bool {
        let context = container.viewContext
        
        // Use a background context for the fetch and update
        let bgContext = container.newBackgroundContext()
        bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        var success = false
        
        bgContext.performAndWait {
            let fetchRequest = NSFetchRequest<Category>(entityName: "Category")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            do {
                let categories = try bgContext.fetch(fetchRequest)
                guard let category = categories.first else { 
                    return
                }
                
                // Update category properties
                if let name = name {
                    category.name = name
                }
                
                if let colorHex = colorHex {
                    category.colorHex = colorHex
                }
                
                // Save in background context
                try bgContext.save()
                success = true
                
            } catch {
                print("Error updating category in background: \(error.localizedDescription)")
            }
        }
        
        guard success else { return false }
        
        // Send notifications to update the UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Notify that the data model has changed
            self.objectWillChange.send()
            
            // Refresh all objects to get latest data
            self.container.viewContext.refreshAllObjects()
            
            // Notify listeners of specific category update
            NotificationCenter.default.post(
                name: .categoryUpdated,
                object: nil,
                userInfo: ["categoryId": id]
            )
            
            // Also send general data change notification
            NotificationCenter.default.post(name: .dataDidChange, object: nil)
        }
        
        return success
    }
    
    // MARK: - Batch Operations
    
    func deleteAllCompletedTasks() -> Int {
        let context = container.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Task")
        fetchRequest.predicate = NSPredicate(format: "isCompleted == %@", NSNumber(value: true))
        
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDeleteRequest.resultType = .resultTypeObjectIDs
        
        do {
            let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
            let objectIDs = result?.result as? [NSManagedObjectID] ?? []
            
            // Merge changes into view context
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
            
            return objectIDs.count
        } catch {
            print("Error deleting completed tasks: \(error.localizedDescription)")
            return 0
        }
    }
}