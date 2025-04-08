//
//  DataController.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import CoreData
import SwiftUI
import WidgetKit

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
    
    // Flag to indicate if reminder attributes exist in the model
    private(set) var hasReminderSupport = false
    
    init() {
        // Initialize with regular NSPersistentContainer for local storage
        container = NSPersistentContainer(name: "TodoListMore")
        
        // Configure for app group sharing (for widget access)
        // Make sure this group ID matches exactly what's in your entitlements files
        let groupID = "group.com.harjot.TodoListApp.SimpleTodoWidget"
        
        print("App - Using app group ID: \(groupID)")
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
        
        if let containerURL = containerURL {
            print("App - Found app group container")
            let storeURL = containerURL.appendingPathComponent("TodoListMore.sqlite")
            print("App - Will store CoreData in shared container")
            
            // Check what's in the container directory without logging paths
            do {
                let contentCount = try FileManager.default.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: nil).count
                print("App - Container has \(contentCount) items")
            } catch {
                print("App - Error checking container contents")
            }
        } else {
            print("App - CRITICAL ERROR: Failed to get container URL for app group: \(groupID)")
            print("App - Check your entitlements and provisioning profiles")
        }
        
        // Get store URL in the shared container
        let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?.appendingPathComponent("TodoListMore.sqlite")
        
        if let storeURL = storeURL {
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [storeDescription]
        }
        
        // Configure container for local storage
        container.loadPersistentStores { description, error in
            if let error = error {
                print("CoreData failed to load: \(error.localizedDescription)")
            } else {
                // Check if reminder attributes exist in the model
                let migrationHelper = CoreDataMigration.shared
                self.hasReminderSupport = migrationHelper.hasReminderAttributes(viewContext: self.container.viewContext)
                
                if self.hasReminderSupport {
                    print("Reminder support is enabled")
                    
                    // Request notification permissions
                    NotificationManager.shared.requestAuthorization { granted in
                        print("Notification permission granted: \(granted)")
                    }
                } else {
                    // Print instructions for adding reminder attributes
                    migrationHelper.printMigrationInstructions()
                }
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
                
                // Debug: Log where CoreData is stored for widget troubleshooting
                let groupID = "group.com.harjot.TodoListApp.SimpleTodoWidget"
                if let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?.appendingPathComponent("TodoListMore.sqlite") {
                    print("App - Saved data to shared container at: \(storeURL)")
                    print("App - File exists: \(FileManager.default.fileExists(atPath: storeURL.path))")
                    
                    // Debug: Count today's tasks
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: Date())
                    let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                    
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Task")
                    fetchRequest.predicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@ AND isCompleted == NO", startOfDay as NSDate, startOfTomorrow as NSDate)
                    
                    do {
                        let tasksCount = try container.viewContext.count(for: fetchRequest)
                        print("App - Number of today's tasks: \(tasksCount)")
                    } catch {
                        print("App - Error counting today's tasks: \(error)")
                    }
                }
                
                // Only refresh changed objects, not all objects
                // This is more efficient than refreshAllObjects()
                
                // Post a notification that data has changed with userInfo if provided
                NotificationCenter.default.post(name: notificationName, object: nil, userInfo: userInfo)
                
                // Refresh widget data immediately
                WidgetCenter.shared.reloadAllTimelines()
                print("App - Refreshing widget timelines after data change")
                
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
    
    func addTask(title: String, description: String, dueDate: Date?, priority: Int16, 
              categoryId: UUID? = nil, reminderType: Int16 = 0, customReminderTime: Double? = nil) -> NSManagedObject? {
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
        
        // Always try to set reminder attributes (force enable)
        do {
            task.setValue(reminderType, forKey: "reminderType")
            
            if let customTime = customReminderTime {
                task.setValue(customTime, forKey: "customReminderTime")
            }
        } catch {
            print("Warning: Failed to set reminder attributes: \(error.localizedDescription)")
        }
        
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
        
        // Schedule reminders if due date and reminder type are set and reminder support is available
        if hasReminderSupport, let dueDate = dueDate, reminderType > 0, let task = task as? Task {
            task.scheduleReminder()
        }
        
        return task
    }
    
    func updateTask(id: UUID, title: String? = nil, description: String? = nil, 
                    dueDate: Date? = nil, removeDueDate: Bool = false,
                    priority: Int16? = nil, isCompleted: Bool? = nil, 
                    categoryId: UUID? = nil, removeCategoryId: Bool = false,
                    reminderType: Int16? = nil, customReminderTime: Double? = nil) -> Bool {
        
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Task")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let tasks = try context.fetch(fetchRequest)
            guard let task = tasks.first else { return false }
            
            // Keep track if we need to reschedule the reminder
            var needsReschedule = false
            
            // Update only provided fields
            if let title = title {
                task.setValue(title, forKey: "title")
                needsReschedule = true
            }
            
            if let description = description {
                task.setValue(description, forKey: "taskDescription")
                needsReschedule = true
            }
            
            if let dueDate = dueDate {
                task.setValue(dueDate, forKey: "dueDate")
                needsReschedule = true
            } else if removeDueDate {
                task.setValue(nil, forKey: "dueDate")
                // Remove any reminders if due date is removed
                if let task = task as? Task {
                    task.removeReminders()
                }
            }
            
            if let priority = priority {
                task.setValue(priority, forKey: "priority")
            }
            
            if let isCompleted = isCompleted {
                task.setValue(isCompleted, forKey: "isCompleted")
                
                // If task is completed, remove its reminders
                if isCompleted, let task = task as? Task {
                    task.removeReminders()
                } else if !isCompleted {
                    needsReschedule = true
                }
            }
            
            // Always try to update reminder settings
            do {
                if let reminderType = reminderType {
                    task.setValue(reminderType, forKey: "reminderType")
                    needsReschedule = true
                }
                
                if let customReminderTime = customReminderTime {
                    task.setValue(customReminderTime, forKey: "customReminderTime")
                    needsReschedule = true
                }
            } catch {
                print("Warning: Failed to update reminder attributes: \(error.localizedDescription)")
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
            var userInfo: [AnyHashable: Any] = ["taskId": id, "categoryId": updatedCategoryId as Any]
            // Include completion status if it was updated
            if let isCompleted = isCompleted {
                userInfo["isCompleted"] = isCompleted
            }
            save(notificationName: .tasksDidChange, userInfo: userInfo)
            
            // Always try to reschedule reminder if needed
            if needsReschedule, let task = task as? Task, let _ = task.dueDate, !task.isCompleted {
                task.scheduleReminder()
            }
            
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
                let newValue = !currentValue
                task.setValue(newValue, forKey: "isCompleted")
                task.setValue(Date(), forKey: "dateModified")
                
                // Save with specific notification and include the new completion status
                save(notificationName: .tasksDidChange, userInfo: ["taskId": id, "isCompleted": newValue])
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
            
            // Refresh widgets after category changes
            WidgetCenter.shared.reloadAllTimelines()
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
                        
                        // Refresh widgets after batch operations
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            } catch {
                print("Error deleting completed tasks: \(error.localizedDescription)")
            }
        }
        
        return deletedCount
    }
}