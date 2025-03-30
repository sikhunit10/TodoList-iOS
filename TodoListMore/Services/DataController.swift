//
//  DataController.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import CoreData
import SwiftUI

// Define notification names for data changes
extension Notification.Name {
    static let dataDidChange = Notification.Name("dataDidChange")
    static let tasksDidChange = Notification.Name("tasksDidChange")
    static let categoriesDidChange = Notification.Name("categoriesDidChange")
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
    func save(notificationName: Notification.Name = .dataDidChange, userInfo: [AnyHashable: Any]? = nil) {
        if container.viewContext.hasChanges {
            do {
                try container.viewContext.save()
                
                // After successful save, ensure all UI elements have the most current data
                objectWillChange.send()
                
                // Only refresh changed objects, not all objects
                // This is more efficient than refreshAllObjects()
                
                // Post a notification that data has changed with userInfo if provided
                NotificationCenter.default.post(name: notificationName, object: nil, userInfo: userInfo)
                
            } catch {
                print("Error saving context: \(error.localizedDescription)")
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
        let taskId = UUID()    
        let now = Date()
        
        // Set values using KVC instead of direct property access
        task.setValue(taskId, forKey: "id")
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
        
        // Save with specific notification
        save(notificationName: .tasksDidChange, userInfo: ["taskId": taskId])
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
            
            var updatedCategoryId: UUID? = nil
            
            if let categoryId = categoryId {
                let categoryFetch: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Category")
                categoryFetch.predicate = NSPredicate(format: "id == %@", categoryId as CVarArg)
                
                let categories = try context.fetch(categoryFetch)
                if let category = categories.first {
                    task.setValue(category, forKey: "category")
                    updatedCategoryId = categoryId
                }
            } else if removeCategoryId {
                task.setValue(nil, forKey: "category")
            }
            
            task.setValue(Date(), forKey: "dateModified")
            
            // Save with specific notification
            let userInfo: [AnyHashable: Any] = ["taskId": id, "categoryId": updatedCategoryId as Any]
            save(notificationName: .tasksDidChange, userInfo: userInfo)
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
                
                // Save with specific notification
                save(notificationName: .tasksDidChange, userInfo: ["taskId": id])
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
        let categoryId = UUID()
        
        category.setValue(categoryId, forKey: "id")
        category.setValue(name, forKey: "name")
        category.setValue(colorHex, forKey: "colorHex")
        
        // Save with specific notification
        save(notificationName: .categoriesDidChange, userInfo: ["categoryId": categoryId])
        return category
    }
    
    // Background context for category operations - reused instead of creating a new one each time
    private lazy var categoryContext: NSManagedObjectContext = {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    
    func updateCategory(id: UUID, name: String? = nil, colorHex: String? = nil) -> Bool {
        var success = false
        
        // Use our shared background context
        categoryContext.performAndWait {
            let fetchRequest = NSFetchRequest<Category>(entityName: "Category")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            do {
                let categories = try categoryContext.fetch(fetchRequest)
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
                try categoryContext.save()
                success = true
                
            } catch {
                print("Error updating category: \(error.localizedDescription)")
            }
        }
        
        guard success else { return false }
        
        // Send notifications to update the UI only once
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Notify that the data model has changed
            self.objectWillChange.send()
            
            // Send targeted notification instead of refreshing all objects
            NotificationCenter.default.post(
                name: .categoriesDidChange, 
                object: nil, 
                userInfo: ["categoryId": id]
            )
        }
        
        return success
    }
    
    // MARK: - Batch Operations
    
    func deleteAllCompletedTasks() -> Int {
        // Use a background context for batch delete operation
        let bgContext = container.newBackgroundContext()
        var deletedCount = 0
        
        bgContext.performAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Task")
            fetchRequest.predicate = NSPredicate(format: "isCompleted == %@", NSNumber(value: true))
            
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs
            
            do {
                let result = try bgContext.execute(batchDeleteRequest) as? NSBatchDeleteResult
                let objectIDs = result?.result as? [NSManagedObjectID] ?? []
                
                // Merge changes into both contexts
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [container.viewContext, bgContext])
                
                deletedCount = objectIDs.count
                
                // Notify of batch change
                if deletedCount > 0 {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.objectWillChange.send()
                        
                        // Send general task change notification
                        NotificationCenter.default.post(
                            name: .tasksDidChange,
                            object: nil,
                            userInfo: ["batchDelete": true]
                        )
                    }
                }
            } catch {
                print("Error deleting completed tasks: \(error.localizedDescription)")
            }
        }
        
        return deletedCount
    }
}