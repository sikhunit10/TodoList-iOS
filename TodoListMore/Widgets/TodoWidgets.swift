import WidgetKit
import SwiftUI
import CoreData

// MARK: - TimelineEntry

/// Shared timeline entry for all widgets
struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let todayTasks: [Task]
    let priorityTasks: [Task]
}

// MARK: - Data Provider

/// Provider that fetches data for the widget
struct TodoWidgetProvider: TimelineProvider {
    let viewContext: NSManagedObjectContext
    
    init() {
        // Set up container with shared app group to access main app's data
        let container = NSPersistentContainer(name: "TodoListMore")
        
        // Use shared App Group container for accessing the same store as the main app
        let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.yourcompany.TodoListMore")?.appendingPathComponent("TodoListMore.sqlite")
        
        if let storeURL = storeURL {
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [storeDescription]
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("Failed to load stores for widget: \(error), \(error.userInfo)")
                // Don't crash in widget, just show empty state
            }
        }
        viewContext = container.viewContext
    }
    
    func placeholder(in context: Context) -> TodoWidgetEntry {
        // Return placeholder data
        TodoWidgetEntry(date: Date(), todayTasks: [], priorityTasks: [])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TodoWidgetEntry) -> Void) {
        let entry = getWidgetEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoWidgetEntry>) -> Void) {
        let currentDate = Date()
        let entry = getWidgetEntry()
        
        // Update every hour or at midnight
        var nextUpdateDate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate) ?? currentDate
        
        // If we're close to midnight, update at midnight
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate)
        if nextUpdateDate > midnight {
            nextUpdateDate = midnight
        }
        
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
    
    // Fetch tasks due today
    private func fetchTodayTasks() -> [Task] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@ AND isCompleted == NO", startOfDay as NSDate, endOfDay as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Task.dueDate, ascending: true)]
        fetchRequest.fetchLimit = 10 // Limit for performance
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching today's tasks: \(error)")
            return []
        }
    }
    
    // Fetch high priority tasks
    private func fetchPriorityTasks() -> [Task] {
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "priority == 3 AND isCompleted == NO") // High priority (3)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Task.dueDate, ascending: true)]
        fetchRequest.fetchLimit = 10 // Limit for performance
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching priority tasks: \(error)")
            return []
        }
    }
}

// MARK: - Widget Views

// Today's Tasks Widget View
struct TodayTasksWidgetView: View {
    let entry: TodoWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("Today's Tasks")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.bottom, 4)
            
            if entry.todayTasks.isEmpty {
                Spacer()
                Text("No tasks due today")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entry.todayTasks) { task in
                            HStack(alignment: .center, spacing: 8) {
                                Circle()
                                    .fill(Color.blue.opacity(0.8))
                                    .frame(width: 8, height: 8)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title ?? "Untitled")
                                        .font(.system(size: 14, weight: .medium))
                                        .lineLimit(1)
                                    
                                    if let dueDate = task.dueDate {
                                        Text(formatTime(dueDate))
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding()
        .widgetURL(URL(string: "todolistmore://today"))
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
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Priority Tasks")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.bottom, 4)
            
            if entry.priorityTasks.isEmpty {
                Spacer()
                Text("No high priority tasks")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entry.priorityTasks) { task in
                            HStack(alignment: .center, spacing: 8) {
                                Circle()
                                    .fill(Color.red.opacity(0.8))
                                    .frame(width: 8, height: 8)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title ?? "Untitled")
                                        .font(.system(size: 14, weight: .medium))
                                        .lineLimit(1)
                                    
                                    if let dueDate = task.dueDate {
                                        Text(formatDate(dueDate))
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding()
        .widgetURL(URL(string: "todolistmore://priority"))
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
        VStack {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 38))
                .foregroundColor(.blue)
            
            Text("Add Task")
                .font(.headline)
                .fontWeight(.medium)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "todolistmore://new"))
    }
}

// MARK: - Widget Configurations

// Today's Tasks Widget
struct TodayTasksWidget: Widget {
    let kind = "TodayTasksWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoWidgetProvider()) { entry in
            TodayTasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Tasks")
        .description("Shows tasks due today")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// Priority Tasks Widget
struct PriorityTasksWidget: Widget {
    let kind = "PriorityTasksWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoWidgetProvider()) { entry in
            PriorityTasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Priority Tasks")
        .description("Shows high priority tasks")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// Quick Add Widget
struct QuickAddTaskWidget: Widget {
    let kind = "QuickAddTaskWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoWidgetProvider()) { entry in
            QuickAddTaskWidgetView()
        }
        .configurationDisplayName("Quick Add Task")
        .description("Quickly add a new task")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget Bundle

// For Widget Extension target use @main, but when included in main app, use a different name
#if EXTENSION
@main
#endif
struct TodoWidgets: WidgetBundle {
    var body: some Widget {
        TodayTasksWidget()
        PriorityTasksWidget()
        QuickAddTaskWidget()
    }
}

// MARK: - Task Extension for Identifiable Conformance
extension Task: Identifiable {}