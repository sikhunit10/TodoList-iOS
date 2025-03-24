//
//  DataController.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import CoreData
import SwiftUI

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
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Category")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let categories = try context.fetch(fetchRequest)
            guard let category = categories.first else { return false }
            
            if let name = name {
                category.setValue(name, forKey: "name")
            }
            
            if let colorHex = colorHex {
                category.setValue(colorHex, forKey: "colorHex")
            }
            
            save()
            return true
        } catch {
            print("Error updating category: \(error.localizedDescription)")
            return false
        }
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