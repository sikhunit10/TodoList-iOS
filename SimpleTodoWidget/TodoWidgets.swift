//
//  TodoWidgets.swift
//  SimpleTodoWidget
//
//  Simplified widget showing only today's tasks
//

import WidgetKit
import SwiftUI
import CoreData

// MARK: - Timeline Entry
struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let todayTasks: [TaskInfo]
    let priorityTasks: [TaskInfo]
    let showPriority: Bool
    let refreshToken: UUID
}

// MARK: - TaskInfo
struct TaskInfo: Identifiable {
    let id: UUID
    let title: String
    let dueDate: Date?
    let isCompleted: Bool
}

// MARK: - CoreData Store Helper
class WidgetCoreDataStore {
    // Default in-memory context to satisfy initialization rules
    var viewContext: NSManagedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    var failedToLoadStore: Bool = false

    init() {
        let container = NSPersistentContainer(name: "TodoListMore")
        let groupID = "group.com.harjot.TodoListApp.SimpleTodoWidget"
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            let storeURL = url.appendingPathComponent("TodoListMore.sqlite")
            let desc = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [desc]
        } else {
            failedToLoadStore = true
        }
        // Load the persistent store asynchronously
        container.loadPersistentStores { [weak self] _, error in
            guard let self = self else { return }
            if error != nil {
                self.failedToLoadStore = true
            }
            // Update to the real viewContext
            self.viewContext = container.viewContext
        }
    }
}

// MARK: - Timeline Provider
struct TodayTasksProvider: TimelineProvider {
    private let store = WidgetCoreDataStore()
    private var context: NSManagedObjectContext { store.viewContext }
    private var failed: Bool { store.failedToLoadStore }

    func placeholder(in context: Context) -> TodoWidgetEntry {
        TodoWidgetEntry(
            date: Date(),
            todayTasks: [],
            priorityTasks: [],
            showPriority: true,
            refreshToken: UUID()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoWidgetEntry) -> Void) {
        completion(
            TodoWidgetEntry(
                date: Date(),
                todayTasks: [],
                priorityTasks: [],
                showPriority: true,
                refreshToken: UUID()
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoWidgetEntry>) -> Void) {
        // Fetch tasks
        let today = fetchTodayTasks()
        let priority = fetchPriorityTasks()
        let now = Date()
        // Two-phase display: priority then today each minute
        let entry1 = TodoWidgetEntry(
            date: now,
            todayTasks: today,
            priorityTasks: priority,
            showPriority: true,
            refreshToken: UUID()
        )
        let entry2 = TodoWidgetEntry(
            date: now.addingTimeInterval(60),
            todayTasks: today,
            priorityTasks: priority,
            showPriority: false,
            refreshToken: UUID()
        )
        // Reload data after two minutes
        let reloadDate = now.addingTimeInterval(120)
        let timeline = Timeline(entries: [entry1, entry2], policy: .after(reloadDate))
        completion(timeline)
    }

    // Removed loadEntry; timeline entries generated in getTimeline

    private func fetchTodayTasks() -> [TaskInfo] {
        if failed { return [] }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let req: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Task")
        req.predicate = NSPredicate(
            format: "dueDate >= %@ AND dueDate < %@ AND isCompleted == NO",
            startOfDay as NSDate,
            startOfTomorrow as NSDate
        )
        req.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        req.fetchLimit = 5
        do {
            let results = try context.fetch(req)
            return results.compactMap { obj in
                guard let id = obj.value(forKey: "id") as? UUID,
                      let title = obj.value(forKey: "title") as? String,
                      let isCompleted = obj.value(forKey: "isCompleted") as? Bool else {
                    return nil
                }
                let dueDate = obj.value(forKey: "dueDate") as? Date
                return TaskInfo(id: id, title: title, dueDate: dueDate, isCompleted: isCompleted)
            }
        } catch {
            return []
        }
    }
    
    private func fetchPriorityTasks() -> [TaskInfo] {
        if failed { return [] }
        let req: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Task")
        req.predicate = NSPredicate(format: "priority == 3 AND isCompleted == NO")
        req.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        req.fetchLimit = 5
        do {
            let results = try context.fetch(req)
            return results.compactMap { obj in
                guard let id = obj.value(forKey: "id") as? UUID,
                      let title = obj.value(forKey: "title") as? String,
                      let isCompleted = obj.value(forKey: "isCompleted") as? Bool else {
                    return nil
                }
                let dueDate = obj.value(forKey: "dueDate") as? Date
                return TaskInfo(id: id, title: title, dueDate: dueDate, isCompleted: isCompleted)
            }
        } catch {
            return []
        }
    }
}

// MARK: - Widget View
struct TodayTasksWidgetView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        // Animate between priority and today every 10 seconds
        TimelineView(.periodic(from: entry.date, by: 10)) { context in
            content(showPriority: isPriorityPhase(date: context.date))
        }
    }

    @ViewBuilder
    private func content(showPriority: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if showPriority {
                // Priority view
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text("Priority Tasks")
                        .font(.subheadline).bold()
                    Spacer()
                }
                if entry.priorityTasks.isEmpty {
                    Spacer()
                    Text("No priority tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    ForEach(entry.priorityTasks.prefix(5)) { task in
                        HStack(spacing: 8) {
                            Image(systemName: "flag.fill")
                                .foregroundColor(.red)
                                .frame(width: 12, height: 12)
                            Text(task.title)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer()
                            if let date = task.dueDate {
                                Text(timeFormatter.string(from: date))
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            } else {
                // Today's view
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text("Today's Tasks")
                        .font(.subheadline).bold()
                    Spacer()
                }
                if entry.todayTasks.isEmpty {
                    Spacer()
                    Text("No tasks today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    ForEach(entry.todayTasks.prefix(5)) { task in
                        HStack(spacing: 8) {
                            Circle()
                                .strokeBorder(Color.blue, lineWidth: 1.5)
                                .frame(width: 12, height: 12)
                            Text(task.title)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer()
                            if let date = task.dueDate {
                                Text(timeFormatter.string(from: date))
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
    }

    private func isPriorityPhase(date: Date) -> Bool {
        let interval = date.timeIntervalSinceReferenceDate
        // every 10s, alternate
        return Int(interval / 10) % 2 == 0
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }
}

// MARK: - Widget Configuration
struct TodayTasksWidget: Widget {
    let kind: String = "TodayTasksWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayTasksProvider()) { entry in
            TodayTasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Tasks")
        .description("Shows tasks due today")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// Preview: show priority then today
#Preview("Widget Demo", as: .systemSmall) {
    TodayTasksWidget()
} timeline: {
    let now = Date()
    let sampleToday = TaskInfo(id: UUID(), title: "Sample Today", dueDate: now.addingTimeInterval(3600), isCompleted: false)
    let samplePriority = TaskInfo(id: UUID(), title: "Urgent Bug Fix", dueDate: now.addingTimeInterval(7200), isCompleted: false)
    return [
        TodoWidgetEntry(
            date: now,
            todayTasks: [sampleToday],
            priorityTasks: [samplePriority],
            showPriority: true,
            refreshToken: UUID()
        )
    ]
}