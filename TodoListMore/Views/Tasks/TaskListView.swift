//
//  TaskListView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import CoreData

struct TaskListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataController: DataController
    
    @State private var showingAddTask = false
    @State private var searchText = ""
    @State private var selectedFilter: TaskFilter = .all
    @State private var selectedTaskId: String? = nil
    @State private var isLoading = true
    @State private var tasks: [NSManagedObject] = []
    @AppStorage("completedTasksVisible") private var completedTasksVisible = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(TaskFilter.allCases) { filter in
                    Text(filter.name).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .onChange(of: selectedFilter) { _ in
                loadTasks()
            }
            
            List {
                if isLoading {
                    // Show placeholders while loading
                    ForEach(0..<5) { index in
                        TaskPlaceholderRow(index: index)
                    }
                } else if tasks.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checklist")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                        
                        Text("No Tasks")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Tap the + button to add a new task")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            showingAddTask = true
                        } label: {
                            Text("Add Task")
                                .fontWeight(.medium)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } else {
                    ForEach(tasks, id: \.self) { task in
                        TaskRow(task: task)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteTask(task)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    toggleTaskCompletion(task)
                                } label: {
                                    let isCompleted = task.value(forKey: "isCompleted") as? Bool ?? false
                                    Label(isCompleted ? "Mark Incomplete" : "Complete", 
                                          systemImage: isCompleted ? "circle" : "checkmark.circle")
                                        .tint(.green)
                                }
                            }
                            .onTapGesture {
                                if let id = task.value(forKey: "id") as? UUID {
                                    selectedTaskId = id.uuidString
                                }
                            }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                loadTasks()
            }
        }
        .searchable(text: $searchText, prompt: "Search tasks")
        .onChange(of: searchText) { _ in
            loadTasks()
        }
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddTask = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            NavigationStack {
                TaskFormView(mode: .add)
            }
            .presentationDetents([.medium, .large])
            .onDisappear {
                loadTasks()
            }
        }
        .sheet(item: $selectedTaskId) { taskId in
            NavigationStack {
                TaskFormView(mode: .edit(taskId))
            }
            .presentationDetents([.medium, .large])
            .onDisappear {
                loadTasks()
            }
        }
        .onAppear {
            loadTasks()
        }
        .onChange(of: completedTasksVisible) { _ in
            loadTasks()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadTasks() {
        isLoading = true
        
        let context = dataController.container.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Task")
        
        // Apply filters
        var predicates: [NSPredicate] = []
        
        // Search text filter
        if !searchText.isEmpty {
            let searchPredicate = NSPredicate(format: "title CONTAINS[cd] %@ OR taskDescription CONTAINS[cd] %@", 
                                             searchText, searchText)
            predicates.append(searchPredicate)
        }
        
        // Status filter based on selected filter and settings
        switch selectedFilter {
        case .active:
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: false)))
        case .completed:
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: true)))
        case .today:
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            predicates.append(NSPredicate(format: "dueDate >= %@ AND dueDate < %@", startOfDay as NSDate, endOfDay as NSDate))
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: false)))
        case .upcoming:
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            predicates.append(NSPredicate(format: "dueDate > %@ AND isCompleted == %@", startOfDay as NSDate, NSNumber(value: false)))
        case .all:
            // If completed tasks are hidden in settings, only show active tasks
            if !completedTasksVisible {
                predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: false)))
            }
        }
        
        if !predicates.isEmpty {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        // Sort by completion status, due date, and then creation date
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "isCompleted", ascending: true),
            NSSortDescriptor(key: "dueDate", ascending: true),
            NSSortDescriptor(key: "dateCreated", ascending: false)
        ]
        
        do {
            tasks = try context.fetch(fetchRequest)
            isLoading = false
        } catch {
            print("Error fetching tasks: \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    private func deleteTask(_ task: NSManagedObject) {
        withAnimation {
            dataController.delete(task)
            loadTasks()
        }
    }
    
    private func toggleTaskCompletion(_ task: NSManagedObject) {
        guard let id = task.value(forKey: "id") as? UUID else { return }
        
        if dataController.toggleTaskCompletion(id: id) {
            // Reload tasks to update the UI
            loadTasks()
        }
    }
}

// Task row view
struct TaskRow: View {
    let task: NSManagedObject
    
    var body: some View {
        HStack {
            Button(action: {}) {
                let isCompleted = task.value(forKey: "isCompleted") as? Bool ?? false
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? .accentColor : .secondary)
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                let title = task.value(forKey: "title") as? String ?? "Untitled Task"
                let isCompleted = task.value(forKey: "isCompleted") as? Bool ?? false
                
                Text(title)
                    .fontWeight(.medium)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted)
                
                HStack(spacing: 12) {
                    if let dueDate = task.value(forKey: "dueDate") as? Date {
                        Label {
                            Text(dueDate, style: .date)
                        } icon: {
                            Image(systemName: "calendar")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    if let category = task.value(forKey: "category") as? NSManagedObject,
                       let categoryName = category.value(forKey: "name") as? String,
                       let colorHex = category.value(forKey: "colorHex") as? String {
                        
                        Label {
                            Text(categoryName)
                        } icon: {
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 8, height: 8)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    } else {
                        // Default styling for tasks without a category
                        Label {
                            Text("Uncategorized")
                        } icon: {
                            Circle()
                                .fill(Color(hex: "#CCCCCC"))
                                .frame(width: 8, height: 8)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Priority indicator
            let priority = task.value(forKey: "priority") as? Int16 ?? 1
            if priority > 1 {
                Image(systemName: priority == 3 ? "exclamationmark.2" : "exclamationmark")
                    .foregroundColor(priority == 3 ? .red : .orange)
                    .font(.caption)
            }
        }
        .contentShape(Rectangle())
    }
}

// Placeholder rows for tasks
struct TaskPlaceholderRow: View {
    let index: Int
    
    private let sampleTitles = ["Complete project proposal", "Buy groceries", "Schedule dentist appointment", "Pay bills", "Call mom"]
    private let sampleDates = [Date().addingTimeInterval(86400), Date().addingTimeInterval(172800), Date().addingTimeInterval(345600), Date().addingTimeInterval(432000), Date().addingTimeInterval(518400)]
    
    var body: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: index % 3 == 0 ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(index % 3 == 0 ? .accentColor : .secondary)
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .redacted(reason: .placeholder)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(sampleTitles[index % sampleTitles.count])
                    .fontWeight(.medium)
                    .foregroundColor(index % 3 == 0 ? .secondary : .primary)
                    .strikethrough(index % 3 == 0)
                    .redacted(reason: .placeholder)
                
                HStack(spacing: 12) {
                    Label {
                        Text(sampleDates[index % sampleDates.count], style: .date)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .redacted(reason: .placeholder)
                }
            }
            
            Spacer()
            
            // Priority indicator
            if index % 4 > 0 {
                Image(systemName: index % 4 == 3 ? "exclamationmark.2" : "exclamationmark")
                    .foregroundColor(index % 4 == 3 ? .red : .orange)
                    .font(.caption)
                    .redacted(reason: .placeholder)
            }
        }
        .contentShape(Rectangle())
    }
}

// Extension to make String identifiable for the sheet
extension String: Identifiable {
    public var id: String { self }
}