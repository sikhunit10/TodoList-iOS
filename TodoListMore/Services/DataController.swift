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
    static let notesDidChange = Notification.Name("notesDidChange")
    static let templatesDidChange = Notification.Name("templatesDidChange")
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
        // IMPORTANT: This group ID must match EXACTLY in:
        // 1. All entitlements files
        // 2. All places where containerURL(forSecurityApplicationGroupIdentifier:) is called
        // 3. Xcode project capabilities configuration
        let groupID = "group.com.harjot.TodoListApp.SimpleTodoWidget"
        
        print("App - Using app group ID: \(groupID)")
        // Obtain shared container URL for app group (fatal on failure)
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            fatalError("App - CRITICAL ERROR: Failed to get container URL for app group: \(groupID). Check entitlements and provisioning profiles.")
        }
        print("App - Found app group container")
        let storeURL = containerURL.appendingPathComponent("TodoListMore.sqlite")
        print("App - Will store CoreData in shared container")
        
        // Check contents of the shared container
        do {
            let contentCount = try FileManager.default.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: nil).count
            print("App - Container has \(contentCount) items")
        } catch {
            print("App - Error checking container contents: \(error.localizedDescription)")
        }
        
        // Configure store URL in the shared container with lightweight migration
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [storeDescription]
        
        // Configure container for local storage
        container.loadPersistentStores { description, error in
            if let error = error {
                print("CoreData failed to load: \(error.localizedDescription)")
                
                // Recovery attempt
                let storeURL = description.url
                print("Attempting recovery for store at: \(String(describing: storeURL))")
                
                // Try to recover by removing failed store
                if let storeURL = storeURL,
                   let storeCoordinator = self.container.persistentStoreCoordinator as? NSPersistentStoreCoordinator {
                    do {
                        // Try to remove the problematic store
                        try storeCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
                        print("Successfully destroyed corrupted store, will create new one on next app launch")
                    } catch {
                        print("Failed to destroy corrupted store: \(error.localizedDescription)")
                    }
                }
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
                
                // Initialize built-in templates (do this after initialization is complete)
                DispatchQueue.main.async {
                    TemplateManager.shared.createBuiltInTemplates()
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
        // Check if we're on the main thread
        let isMainThread = Thread.isMainThread
        
        if container.viewContext.hasChanges {
            do {
                // Perform save on the appropriate thread
                if isMainThread {
                    // We're already on the main thread
                    try container.viewContext.save()
                } else {
                    // Dispatch to main thread for viewContext operations
                    DispatchQueue.main.sync {
                        do {
                            try container.viewContext.save()
                        } catch {
                            print("Error saving context on main thread: \(error.localizedDescription)")
                        }
                    }
                }
                
                // After successful save, ensure all UI elements have the most current data
                // Dispatch UI updates to main thread
                if isMainThread {
                    objectWillChange.send()
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.objectWillChange.send()
                    }
                }
                
                // Debug: Log where CoreData is stored for widget troubleshooting
                let groupID = "group.com.harjot.TodoListApp.SimpleTodoWidget"
                if let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?.appendingPathComponent("TodoListMore.sqlite") {
                    print("App - Saved data to shared container at: \(storeURL)")
                    print("App - File exists: \(FileManager.default.fileExists(atPath: storeURL.path))")
                    
                    // Debug: Count today's tasks
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: Date())
                    // Safely compute start of tomorrow, fallback to 24h interval
                    let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay)
                        ?? startOfDay.addingTimeInterval(24 * 60 * 60)
                    
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Task")
                    fetchRequest.predicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@ AND isCompleted == NO", startOfDay as NSDate, startOfTomorrow as NSDate)
                    
                    do {
                        let context = isMainThread ? container.viewContext : container.newBackgroundContext()
                        let tasksCount = try context.count(for: fetchRequest)
                        print("App - Number of today's tasks: \(tasksCount)")
                    } catch {
                        print("App - Error counting today's tasks: \(error)")
                    }
                }
                
                // Post a notification that data has changed with userInfo if provided
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: notificationName, object: nil, userInfo: userInfo)
                }
                
                // Refresh widget data immediately to ensure timely updates (even if app is backgrounded)
                if #available(iOS 14.0, *) {
                    if Thread.isMainThread {
                        WidgetCenter.shared.reloadAllTimelines()
                    } else {
                        DispatchQueue.main.async {
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    }
                    print("App - Refreshing widget timelines after data change (immediate)")
                }
                // Also schedule a delayed reload to catch any late writes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    WidgetCenter.shared.reloadAllTimelines()
                    print("App - Refreshing widget timelines after data change (delayed)")
                }
                
            } catch {
                print("Error saving context: \(error.localizedDescription)")
                print("Failed to save data: \(error.localizedDescription)")
                
                // Recovery attempt for database issues
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    self?.attemptRecovery()
                }
            }
        }
    }
    
    // Helper method to attempt recovery of corrupted database
    private func attemptRecovery() {
        print("Attempting CoreData recovery...")
        // Reset the view context to clear any failed transactions
        container.viewContext.reset()
    }
    
    // Delete objects
    func delete(_ object: NSManagedObject) {
        container.viewContext.delete(object)
        save()
    }
    
    // MARK: - Task Operations
    
    func addTask(title: String, description: String, dueDate: Date?, priority: Int16,
                 recurrence: Int16 = RecurrenceRule.none.rawValue,
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
        // Set recurrence rule
        task.setValue(recurrence, forKey: "recurrence")
        
        // Always try to set reminder attributes (force enable)
        do {
            task.setValue(reminderType, forKey: "reminderType")
            if let customTime = customReminderTime {
                task.setValue(customTime, forKey: "customReminderTime")
            }
        } catch {
            assertionFailure("Failed to set reminder attributes: \(error.localizedDescription)")
        }
        
        // If we have a category ID, find that category and associate it
        if let categoryId = categoryId {
            // Use a transaction to ensure category fetch is atomic
            context.performAndWait {
                let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Category")
                fetchRequest.predicate = NSPredicate(format: "id == %@", categoryId as CVarArg)
                
                do {
                    let categories = try context.fetch(fetchRequest)
                    if let category = categories.first {
                        task.setValue(category, forKey: "category")
                    } else {
                        print("Category with ID \(categoryId) not found")
                    }
                } catch {
                    print("Error fetching category: \(error.localizedDescription)")
                }
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
                    priority: Int16? = nil, recurrence: Int16? = nil, isCompleted: Bool? = nil,
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
            // Update recurrence rule if provided
            if let recurrence = recurrence {
                task.setValue(recurrence, forKey: "recurrence")
                needsReschedule = true
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
                assertionFailure("Failed to update reminder attributes: \(error.localizedDescription)")
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
            // Ensure we have a Task object
            guard let firstObj = tasks.first, let task = firstObj as? Task else {
                return false
            }
            let currentValue = task.isCompleted
            let rule = task.recurrenceRuleEnum
            // Handle recurring tasks: when marking complete, schedule next occurrence instead of completing
            if !currentValue && rule != .none {
                if let dueDate = task.dueDate {
                    let calendar = Calendar.current
                    var nextDate: Date?
                    switch rule {
                    case .daily:
                        nextDate = calendar.date(byAdding: .day, value: 1, to: dueDate)
                    case .weekly:
                        nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: dueDate)
                    case .monthly:
                        nextDate = calendar.date(byAdding: .month, value: 1, to: dueDate)
                    case .yearly:
                        nextDate = calendar.date(byAdding: .year, value: 1, to: dueDate)
                    default:
                        break
                    }
                    if let next = nextDate {
                        task.dueDate = next
                    }
                }
                task.dateModified = Date()
                // Schedule reminder for next occurrence if supported
                if hasReminderSupport, let _ = task.dueDate {
                    task.scheduleReminder()
                }
                save(notificationName: .tasksDidChange, userInfo: ["taskId": id, "isRecurring": true])
                return true
            }
            // Non-recurring or toggling back to incomplete: standard behavior
            let newValue = !currentValue
            task.isCompleted = newValue
            task.dateModified = Date()
            if newValue {
                // Remove any existing reminders when marked complete
                task.removeReminders()
            }
            save(notificationName: .tasksDidChange, userInfo: ["taskId": id, "isCompleted": newValue])
            return true
        } catch {
            print("Error toggling task completion: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Category Operations
    
    /// Create a new category with optional icon and note
    func addCategory(name: String, colorHex: String, icon: String? = nil, note: String? = nil) -> NSManagedObject? {
        let context = container.viewContext
        
        let category = NSEntityDescription.insertNewObject(forEntityName: "Category", into: context)
        let categoryId = UUID()
        
        category.setValue(categoryId, forKey: "id")
        category.setValue(name, forKey: "name")
        category.setValue(colorHex, forKey: "colorHex")
        if let icon = icon {
            category.setValue(icon, forKey: "icon")
        }
        if let note = note {
            category.setValue(note, forKey: "note")
        }
        
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
    
    /// Update existing category fields: name, colorHex, icon, and note
    func updateCategory(id: UUID,
                        name: String? = nil,
                        colorHex: String? = nil,
                        icon: String? = nil,
                        note: String? = nil) -> Bool {
        // Create a local completion indicator
        let completion = CompletionIndicator()
        
        // Capture UUID value for async use, avoiding the need to capture self
        let categoryId = id
        
        // Use our shared background context with performAndWait to ensure completion
        categoryContext.perform { [weak self] in
            guard let self = self else {
                completion.fail()
                return
            }
            
            let fetchRequest = NSFetchRequest<Category>(entityName: "Category")
            fetchRequest.predicate = NSPredicate(format: "id == %@", categoryId as CVarArg)
            
            do {
                let categories = try self.categoryContext.fetch(fetchRequest)
                guard let category = categories.first else { 
                    completion.fail()
                    return
                }
                
                // Update category properties
                if let name = name {
                    category.name = name
                }
                if let colorHex = colorHex {
                    category.colorHex = colorHex
                }
                if let icon = icon {
                    category.setValue(icon, forKey: "icon")
                }
                if let note = note {
                    category.setValue(note, forKey: "note")
                }
                
                // Save in background context
                try self.categoryContext.save()
                
                // Signal success before UI updates
                completion.succeed()
                
                // Since we're in a background queue, dispatch UI updates to main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // Notify that the data model has changed
                    self.objectWillChange.send()
                    
                    // Send targeted notification instead of refreshing all objects
                    NotificationCenter.default.post(
                        name: .categoriesDidChange, 
                        object: nil, 
                        userInfo: ["categoryId": categoryId]
                    )
                    
                    // Refresh widgets after category changes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
                
            } catch {
                print("Error updating category: \(error.localizedDescription)")
                completion.fail()
            }
        }
        
        // Wait for the operation to complete with a reasonable timeout
        return completion.waitForCompletion(timeout: 3.0)
    }
    
    // Helper class for thread-safe completion tracking
    private class CompletionIndicator {
        private var isCompleted = false
        private var didSucceed = false
        private let lock = NSLock()
        
        func succeed() {
            lock.lock()
            defer { lock.unlock() }
            isCompleted = true
            didSucceed = true
        }
        
        func fail() {
            lock.lock()
            defer { lock.unlock() }
            isCompleted = true
            didSucceed = false
        }
        
        func waitForCompletion(timeout: TimeInterval) -> Bool {
            let startTime = Date()
            
            while Date().timeIntervalSince(startTime) < timeout {
                lock.lock()
                let completed = isCompleted
                let success = didSucceed
                lock.unlock()
                
                if completed {
                    return success
                }
                
                // Sleep briefly to avoid high CPU usage
                Thread.sleep(forTimeInterval: 0.05)
            }
            
            print("Warning: Timed out waiting for category update")
            return false
        }
    }
    
    // MARK: - Note Operations
    
    func addNote(content: String, tags: String = "") -> NSManagedObject? {
        let context = container.viewContext
        
        let note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: context)
        let noteId = UUID()
        let now = Date()
        
        note.setValue(noteId, forKey: "id")
        note.setValue(content, forKey: "content")
        note.setValue(tags, forKey: "tags")
        note.setValue(now, forKey: "dateCreated")
        note.setValue(now, forKey: "dateModified")
        
        save(notificationName: .notesDidChange, userInfo: ["noteId": noteId])
        return note
    }
    
    func updateNote(id: UUID, content: String? = nil, tags: String? = nil) -> Bool {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Note")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let notes = try context.fetch(fetchRequest)
            guard let note = notes.first else { return false }
            
            if let content = content {
                note.setValue(content, forKey: "content")
            }
            
            if let tags = tags {
                note.setValue(tags, forKey: "tags")
            }
            
            note.setValue(Date(), forKey: "dateModified")
            
            save(notificationName: .notesDidChange, userInfo: ["noteId": id])
            return true
        } catch {
            print("Error updating note: \(error.localizedDescription)")
            return false
        }
    }
    
    func deleteNote(id: UUID) -> Bool {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Note")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let notes = try context.fetch(fetchRequest)
            guard let note = notes.first else { return false }
            
            context.delete(note)
            save(notificationName: .notesDidChange, userInfo: ["noteId": id, "deleted": true])
            return true
        } catch {
            print("Error deleting note: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Template Operations
    
    func createTemplate(name: String, description: String = "", category: String = "General", icon: String = "list.bullet", tasks: [TemplateTaskData], isBuiltIn: Bool = false) -> NSManagedObject? {
        let context = container.viewContext
        
        let template = NSEntityDescription.insertNewObject(forEntityName: "TaskTemplate", into: context)
        let templateId = UUID()
        let now = Date()
        
        template.setValue(templateId, forKey: "id")
        template.setValue(name, forKey: "name")
        template.setValue(description, forKey: "templateDescription")
        template.setValue(category, forKey: "category")
        template.setValue(icon, forKey: "icon")
        template.setValue(isBuiltIn, forKey: "isBuiltIn")
        template.setValue(now, forKey: "dateCreated")
        template.setValue(now, forKey: "dateModified")
        
        print("DEBUG: Creating template '\(name)' with \(tasks.count) tasks")
        
        // Create template tasks
        for (index, taskData) in tasks.enumerated() {
            let templateTask = NSEntityDescription.insertNewObject(forEntityName: "TemplateTask", into: context)
            templateTask.setValue(UUID(), forKey: "id")
            templateTask.setValue(taskData.title, forKey: "title")
            templateTask.setValue(taskData.description, forKey: "taskDescription")
            templateTask.setValue(taskData.priority.rawValue, forKey: "priority")
            templateTask.setValue(taskData.dueDateOffset, forKey: "dueDateOffset")
            templateTask.setValue(taskData.categoryName, forKey: "categoryName")
            templateTask.setValue(Int16(index), forKey: "orderIndex")
            templateTask.setValue(template, forKey: "template")
            
            print("DEBUG: Created template task: \(taskData.title) (priority: \(taskData.priority.rawValue), offset: \(taskData.dueDateOffset))")
        }
        
        save(notificationName: .templatesDidChange, userInfo: ["templateId": templateId])
        print("DEBUG: Template '\(name)' created with ID: \(templateId)")
        return template
    }
    
    func updateTemplate(id: UUID, name: String? = nil, description: String? = nil, category: String? = nil, icon: String? = nil, tasks: [TemplateTaskData]? = nil) -> Bool {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "TaskTemplate")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let templates = try context.fetch(fetchRequest)
            guard let template = templates.first else { return false }
            
            if let name = name {
                template.setValue(name, forKey: "name")
            }
            if let description = description {
                template.setValue(description, forKey: "templateDescription")
            }
            if let category = category {
                template.setValue(category, forKey: "category")
            }
            if let icon = icon {
                template.setValue(icon, forKey: "icon")
            }
            
            // Update tasks if provided
            if let tasks = tasks {
                // Remove existing template tasks
                if let existingTasks = template.value(forKey: "templateTasks") as? Set<NSManagedObject> {
                    for task in existingTasks {
                        context.delete(task)
                    }
                }
                
                // Create new template tasks
                for (index, taskData) in tasks.enumerated() {
                    let templateTask = NSEntityDescription.insertNewObject(forEntityName: "TemplateTask", into: context)
                    templateTask.setValue(UUID(), forKey: "id")
                    templateTask.setValue(taskData.title, forKey: "title")
                    templateTask.setValue(taskData.description, forKey: "taskDescription")
                    templateTask.setValue(taskData.priority.rawValue, forKey: "priority")
                    templateTask.setValue(taskData.dueDateOffset, forKey: "dueDateOffset")
                    templateTask.setValue(taskData.categoryName, forKey: "categoryName")
                    templateTask.setValue(Int16(index), forKey: "orderIndex")
                    templateTask.setValue(template, forKey: "template")
                }
            }
            
            template.setValue(Date(), forKey: "dateModified")
            save(notificationName: .templatesDidChange, userInfo: ["templateId": id])
            return true
        } catch {
            print("Error updating template: \(error.localizedDescription)")
            return false
        }
    }
    
    func deleteTemplate(id: UUID) -> Bool {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "TaskTemplate")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let templates = try context.fetch(fetchRequest)
            guard let template = templates.first else { return false }
            
            context.delete(template)
            save(notificationName: .templatesDidChange, userInfo: ["templateId": id, "deleted": true])
            return true
        } catch {
            print("Error deleting template: \(error.localizedDescription)")
            return false
        }
    }
    
    func applyTemplate(templateId: UUID, baseDate: Date = Date()) -> Bool {
        print("DEBUG: Starting template application for ID: \(templateId)")
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "TaskTemplate")
        fetchRequest.predicate = NSPredicate(format: "id == %@", templateId as CVarArg)
        
        do {
            let templates = try context.fetch(fetchRequest)
            print("DEBUG: Found \(templates.count) templates")
            guard let template = templates.first else { 
                print("DEBUG: No template found with ID: \(templateId)")
                return false 
            }
            
            let templateName = template.value(forKey: "name") as? String ?? "Unknown"
            print("DEBUG: Found template: \(templateName)")
            
            // Get template tasks
            let templateTasksRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "TemplateTask")
            templateTasksRequest.predicate = NSPredicate(format: "template == %@", template)
            templateTasksRequest.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
            
            let templateTasks = try context.fetch(templateTasksRequest)
            print("DEBUG: Found \(templateTasks.count) template tasks")
            
            if templateTasks.isEmpty {
                print("DEBUG: No template tasks found for template: \(templateName)")
                return false
            }
            
            // Track template application
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.amplitude.track(
                eventType: "template_applied",
                eventProperties: [
                    "template_id": templateId.uuidString,
                    "template_name": templateName,
                    "task_count": templateTasks.count
                ]
            )
            
            var successCount = 0
            // Create tasks from template
            for (index, templateTask) in templateTasks.enumerated() {
                let title = templateTask.value(forKey: "title") as? String ?? ""
                let description = templateTask.value(forKey: "taskDescription") as? String ?? ""
                let priority = templateTask.value(forKey: "priority") as? Int16 ?? 1
                let dueDateOffset = templateTask.value(forKey: "dueDateOffset") as? Int32 ?? 0
                let categoryName = templateTask.value(forKey: "categoryName") as? String ?? ""
                
                print("DEBUG: Processing task \(index + 1): \(title) (priority: \(priority), offset: \(dueDateOffset))")
                
                // Calculate due date
                var dueDate: Date? = nil
                if dueDateOffset != 0 {
                    dueDate = Calendar.current.date(byAdding: .day, value: Int(dueDateOffset), to: baseDate)
                    print("DEBUG: Calculated due date: \(dueDate?.description ?? "nil")")
                }
                
                // Find category by name
                var categoryId: UUID? = nil
                if !categoryName.isEmpty {
                    let categoryRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Category")
                    categoryRequest.predicate = NSPredicate(format: "name == %@", categoryName)
                    if let category = try? context.fetch(categoryRequest).first {
                        categoryId = category.value(forKey: "id") as? UUID
                        print("DEBUG: Found category: \(categoryName) with ID: \(categoryId?.uuidString ?? "nil")")
                    } else {
                        print("DEBUG: Category not found: \(categoryName)")
                    }
                }
                
                // Create the task
                if let newTask = addTask(
                    title: title,
                    description: description,
                    dueDate: dueDate,
                    priority: priority,
                    categoryId: categoryId
                ) {
                    successCount += 1
                    print("DEBUG: Successfully created task: \(title)")
                } else {
                    print("DEBUG: Failed to create task: \(title)")
                }
            }
            
            print("DEBUG: Successfully created \(successCount) out of \(templateTasks.count) tasks")
            return successCount > 0
        } catch {
            print("ERROR applying template: \(error.localizedDescription)")
            return false
        }
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
                
                // Create a barrier to ensure proper synchronization across contexts
                let barrier = DispatchGroup()
                barrier.enter()
                
                // Merge changes into main context on the main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        barrier.leave()
                        return
                    }
                    
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.container.viewContext])
                    barrier.leave()
                }
                
                // Wait for main context update to complete (with timeout)
                _ = barrier.wait(timeout: .now() + 1.0)
                
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