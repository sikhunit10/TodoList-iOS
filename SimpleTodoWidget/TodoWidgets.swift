//
//  TodoWidgets.swift
//  SimpleTodoWidget
//
//  Created by Harjot Singh on 05/04/25.
//

import WidgetKit
import SwiftUI
import CoreData

// MARK: - TimelineEntry

struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let todayTasks: [TaskInfo]
    let priorityTasks: [TaskInfo]
}

// A lightweight task info struct to avoid CoreData objects in the widget
struct TaskInfo: Identifiable {
    let id: UUID
    let title: String
    let dueDate: Date?
    let priority: Int
    let isCompleted: Bool
}

// MARK: - Data Provider

// Helper class to hold CoreData state (using class instead of struct to allow mutation in closures)
class WidgetCoreDataStore {
    var viewContext: NSManagedObjectContext
    var failedToLoadStore = false
    
    init() {
        // Try to find the CoreData model
        print("Widget - Looking for CoreData model")
        
        // First, create an in-memory context as a fallback
        let tempContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        self.viewContext = tempContext
        self.failedToLoadStore = true
        
        // Try to initialize a container without model (just for debugging)
        let container = NSPersistentContainer(name: "TodoListMore")
        
        // Set up shared container store (will use sample data since model isn't found)
        setupStore(container: container)
    }
    
    private func setupStore(container: NSPersistentContainer) {
        // Use shared App Group container for accessing the same store as the main app
        let groupID = "group.com.harjot.TodoListApp.SimpleTodoWidget"
        print("Widget - Using app group ID: \(groupID)")
        
        // Check if we can get the container URL for the app group
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
        
        if let containerURL = containerURL {
            print("Widget - Found app group container")
            let storeURL = containerURL.appendingPathComponent("TodoListMore.sqlite")
            
            let fileExists = FileManager.default.fileExists(atPath: storeURL.path)
            print("Widget - Database file exists: \(fileExists)")
            
            // Set up the store description to use the shared container
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [storeDescription]
            
            // Check container contents without logging paths
            do {
                let contentCount = try FileManager.default.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: nil).count
                print("Widget - Container has \(contentCount) items")
            } catch {
                print("Widget - Error checking container contents")
            }
        } else {
            print("Widget - CRITICAL ERROR: Failed to get container URL for app group")
            print("Widget - This usually means the app group doesn't exist or isn't properly configured")
            self.failedToLoadStore = true
        }
        
        // Attempt to load the store
        let group = DispatchGroup()
        group.enter()
        
        container.loadPersistentStores { [weak self] (_, error) in
            if let error = error {
                print("Widget - Failed to load stores: \(error.localizedDescription)")
                self?.failedToLoadStore = true
            } else {
                print("Widget - Successfully loaded persistent store")
                // Store loaded successfully, update flag
                self?.failedToLoadStore = false
                // Update view context
                self?.viewContext = container.viewContext
            }
            group.leave()
        }
        
        // Wait for store loading to complete (with timeout)
        let result = group.wait(timeout: .now() + 2.0)
        if result == .timedOut {
            print("Widget - Timed out waiting for store to load")
            self.failedToLoadStore = true
        }
    }
}

struct TodoWidgetProvider: TimelineProvider {
    // Use a class to handle CoreData operations
    private let coreDataStore = WidgetCoreDataStore()
    
    // Computed property to access the view context
    var viewContext: NSManagedObjectContext {
        return coreDataStore.viewContext
    }
    
    // Property to check if store loading failed
    var failedToLoadStore: Bool {
        return coreDataStore.failedToLoadStore
    }
    
    init() {
        // CoreData setup is now handled by WidgetCoreDataStore
        print("Widget - Provider initialized")
        
        // Log CoreData status
        if failedToLoadStore {
            print("Widget - CoreData store loading failed, will use sample data")
        } else {
            print("Widget - CoreData store loaded successfully")
        }
    }
    
    func placeholder(in context: Context) -> TodoWidgetEntry {
        // Return empty placeholder data
        return TodoWidgetEntry(date: Date(), todayTasks: [], priorityTasks: [])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TodoWidgetEntry) -> Void) {
        let entry = getWidgetEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoWidgetEntry>) -> Void) {
        let currentDate = Date()
        let entry = getWidgetEntry()
        
        // Add debug info
        print("Widget - Timeline update. Today's tasks count: \(entry.todayTasks.count)")
        if entry.todayTasks.isEmpty {
            print("Widget - No today's tasks found!")
        } else {
            print("Widget - Today's tasks: \(entry.todayTasks.map { $0.title })")
        }
        
        // Set shorter update interval for frequent refreshes
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate) ?? currentDate
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
    
    // Helper to get data for the widget
    private func getWidgetEntry() -> TodoWidgetEntry {
        // Get today's tasks
        let todayTasks = fetchTodayTasks()
        
        // Get priority tasks
        let priorityTasks = fetchPriorityTasks()
        
        return TodoWidgetEntry(date: Date(), todayTasks: todayTasks, priorityTasks: priorityTasks)
    }
    
    // Return a single placeholder task for error cases rather than empty array
    private func getEmptyTasks() -> [TaskInfo] {
        print("Widget - No tasks available to display, creating placeholder")
        // Create a single invisible placeholder to prevent system error icons
        return [
            TaskInfo(
                id: UUID(), 
                title: "No tasks available", 
                dueDate: Date(), 
                priority: 1, 
                isCompleted: false
            )
        ]
    }
    
    // Fetch tasks due today
    private func fetchTodayTasks() -> [TaskInfo] {
        // If we already know the store failed to load, just return empty array
        if failedToLoadStore {
            print("Widget - Store failed to load, no tasks to display")
            return getEmptyTasks()
        }
        
        print("Widget - Attempting to fetch today's tasks")
        
        // First try to count all tasks to see if CoreData is working
        let allTasksRequest = NSFetchRequest<NSManagedObject>(entityName: "Task")
        
        // Check if we can access CoreData at all
        do {
            let allTasksCount = try viewContext.count(for: allTasksRequest)
            print("Widget - Total number of tasks in CoreData: \(allTasksCount)")
            
            // If CoreData seems empty, return empty array
            if allTasksCount == 0 {
                print("Widget - No tasks found in CoreData")
                return getEmptyTasks()
            }
        } catch {
            print("Widget - Error accessing CoreData: \(error)")
            return getEmptyTasks()
        }
        
        // Get today's date range using the same method as the main app
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // For debugging
        print("Widget - Today's range: \(startOfDay) to \(startOfTomorrow)")
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Task")
        let predicateString = "dueDate >= %@ AND dueDate < %@ AND isCompleted == NO"
        fetchRequest.predicate = NSPredicate(format: predicateString, startOfDay as NSDate, startOfTomorrow as NSDate)
        print("Widget - Using predicate: \(predicateString) with dates: \(startOfDay) to \(startOfTomorrow)")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        fetchRequest.fetchLimit = 5 // Limit for performance
        
        do {
            let fetchedTasks = try viewContext.fetch(fetchRequest)
            return fetchedTasks.compactMap { task -> TaskInfo? in
                guard let id = task.value(forKey: "id") as? UUID,
                      let title = task.value(forKey: "title") as? String,
                      let priority = task.value(forKey: "priority") as? Int16,
                      let isCompleted = task.value(forKey: "isCompleted") as? Bool else {
                    return nil
                }
                
                let dueDate = task.value(forKey: "dueDate") as? Date
                
                return TaskInfo(
                    id: id,
                    title: title,
                    dueDate: dueDate,
                    priority: Int(priority),
                    isCompleted: isCompleted
                )
            }
        } catch {
            print("Error fetching today's tasks for widget: \(error)")
            return []
        }
    }
    
    // Fetch high priority tasks
    private func fetchPriorityTasks() -> [TaskInfo] {
        // If we already know the store failed to load, just return empty array
        if failedToLoadStore {
            print("Widget - Store failed to load, no priority tasks to display")
            return getEmptyTasks()
        }
        
        print("Widget - Attempting to fetch priority tasks")
        
        // Check if we can access CoreData at all
        let allTasksRequest = NSFetchRequest<NSManagedObject>(entityName: "Task")
        do {
            let allTasksCount = try viewContext.count(for: allTasksRequest)
            print("Widget - Priority task check: \(allTasksCount) total tasks found")
            
            if allTasksCount == 0 {
                // If there are no tasks at all, return empty array
                print("Widget - No tasks at all, no priority tasks to display")
                return getEmptyTasks()
            }
        } catch {
            print("Widget - Error in fetchPriorityTasks: \(error)")
            return getEmptyTasks()
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Task")
        fetchRequest.predicate = NSPredicate(format: "priority == 3 AND isCompleted == NO") // High priority (3)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        fetchRequest.fetchLimit = 5 // Limit for performance
        
        do {
            let fetchedTasks = try viewContext.fetch(fetchRequest)
            return fetchedTasks.compactMap { task -> TaskInfo? in
                guard let id = task.value(forKey: "id") as? UUID,
                      let title = task.value(forKey: "title") as? String,
                      let priority = task.value(forKey: "priority") as? Int16,
                      let isCompleted = task.value(forKey: "isCompleted") as? Bool else {
                    return nil
                }
                
                let dueDate = task.value(forKey: "dueDate") as? Date
                
                return TaskInfo(
                    id: id,
                    title: title,
                    dueDate: dueDate,
                    priority: Int(priority),
                    isCompleted: isCompleted
                )
            }
        } catch {
            print("Error fetching priority tasks for widget: \(error)")
            return []
        }
    }
}

// MARK: - Widget Views

// Today's Tasks Widget View
struct TodayTasksWidgetView: View {
    let entry: TodoWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .semibold))
                Text("Today's Tasks")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.bottom, 4)
            
            if entry.todayTasks.isEmpty || (entry.todayTasks.count == 1 && entry.todayTasks[0].title == "No tasks available") {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.blue.opacity(0.7))
                    Text("No tasks due today")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                // Tasks list with improved design
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(entry.todayTasks.prefix(4)) { task in
                        HStack(spacing: 8) {
                            // Task status indicator
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.blue, lineWidth: 1.5)
                                    .frame(width: 14, height: 14)
                                
                                if task.isCompleted {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            
                            // Task title with one-line overflow ellipsis
                            Text(task.title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Spacer(minLength: 4)
                            
                            // Time badge
                            if let dueDate = task.dueDate {
                                Text(formatTime(dueDate))
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    
                    // Show count of additional tasks if any
                    if entry.todayTasks.count > 4 {
                        Text("+ \(entry.todayTasks.count - 4) more")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "todolistmore://today"))
        .privacySensitive(false)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// Priority Tasks Widget View
struct PriorityTasksWidgetView: View {
    let entry: TodoWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                    .font(.system(size: 14, weight: .semibold))
                Text("Priority Tasks")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.bottom, 4)
            
            if entry.priorityTasks.isEmpty || (entry.priorityTasks.count == 1 && entry.priorityTasks[0].title == "No tasks available") {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "flag.slash")
                        .font(.system(size: 20))
                        .foregroundColor(.red.opacity(0.7))
                    Text("No high priority tasks")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                // Tasks list with improved design
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(entry.priorityTasks.prefix(4)) { task in
                        HStack(spacing: 8) {
                            // Priority indicator
                            Image(systemName: "flag.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                                .frame(width: 14, height: 14)
                            
                            // Task title with one-line overflow ellipsis
                            Text(task.title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Spacer(minLength: 4)
                            
                            // Date badge
                            if let dueDate = task.dueDate {
                                Text(formatDate(dueDate))
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    
                    // Show count of additional tasks if any
                    if entry.priorityTasks.count > 4 {
                        Text("+ \(entry.priorityTasks.count - 4) more")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "todolistmore://priority"))
        .privacySensitive(false)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// Quick Add Task Widget View
struct QuickAddTaskWidgetView: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                // Animated-looking plus icon
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 52, height: 52)
                        .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                Text("Add Task")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Tap to create")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "todolistmore://new"))
        .privacySensitive(false)
    }
}

// MARK: - Widget Configurations

// Today's Tasks Widget
struct TodayTasksWidget: Widget {
    static let kind = "TodayTasksWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TodoWidgetProvider()) { entry in
            TodayTasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Tasks")
        .description("Shows tasks due today")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// Priority Tasks Widget
struct PriorityTasksWidget: Widget {
    static let kind = "PriorityTasksWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TodoWidgetProvider()) { entry in
            PriorityTasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Priority Tasks")
        .description("Shows high priority tasks")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// Quick Add Widget
struct QuickAddTaskWidget: Widget {
    static let kind = "QuickAddTaskWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TodoWidgetProvider()) { entry in
            QuickAddTaskWidgetView()
        }
        .configurationDisplayName("Quick Add Task")
        .description("Quickly add a new task")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// MARK: - Preview Providers

#Preview("Today Tasks (Small)", as: .systemSmall) {
    TodayTasksWidget()
} timeline: {
    TodoWidgetEntry(
        date: .now,
        todayTasks: [
            TaskInfo(id: UUID(), title: "Complete project", dueDate: Date().addingTimeInterval(3600), priority: 2, isCompleted: false),
            TaskInfo(id: UUID(), title: "Call client", dueDate: Date().addingTimeInterval(7200), priority: 3, isCompleted: false)
        ],
        priorityTasks: []
    )
}

// Medium size no longer supported
// #Preview("Today Tasks (Medium)", as: .systemMedium) {
//     TodayTasksWidget()
// } timeline: {
//     TodoWidgetEntry(
//         date: .now,
//         todayTasks: [
//             TaskInfo(id: UUID(), title: "Complete project", dueDate: Date().addingTimeInterval(3600), priority: 2, isCompleted: false),
//             TaskInfo(id: UUID(), title: "Call client", dueDate: Date().addingTimeInterval(7200), priority: 3, isCompleted: false),
//             TaskInfo(id: UUID(), title: "Prepare presentation", dueDate: Date().addingTimeInterval(10800), priority: 2, isCompleted: false)
//         ],
//         priorityTasks: []
//     )
// }

#Preview("Priority Tasks", as: .systemSmall) {
    PriorityTasksWidget()
} timeline: {
    TodoWidgetEntry(
        date: .now,
        todayTasks: [],
        priorityTasks: [
            TaskInfo(id: UUID(), title: "Critical bug fix", dueDate: Date().addingTimeInterval(86400), priority: 3, isCompleted: false),
            TaskInfo(id: UUID(), title: "Client emergency", dueDate: Date().addingTimeInterval(172800), priority: 3, isCompleted: false)
        ]
    )
}

#Preview("Quick Add", as: .systemSmall) {
    QuickAddTaskWidget()
} timeline: {
    TodoWidgetEntry(date: .now, todayTasks: [], priorityTasks: [])
}