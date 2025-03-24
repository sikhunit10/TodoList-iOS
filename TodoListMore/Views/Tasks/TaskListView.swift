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
    @AppStorage("completedTasksVisible") private var completedTasksVisible = true
    
    // Define sort descriptors
    private static let sortDescriptors = [
        SortDescriptor(\Task.isCompleted, order: .forward),
        SortDescriptor(\Task.dueDate, order: .forward),
        SortDescriptor(\Task.dateCreated, order: .reverse)
    ]
    
    // Use FetchRequest to automatically update when data changes
    @FetchRequest(
        sortDescriptors: sortDescriptors,
        animation: .default
    ) private var tasks: FetchedResults<Task>
    
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
                updateFetchRequest()
            }
            
            List {
                if tasks.isEmpty {
                    EmptyTaskView(onAddTask: { showingAddTask = true })
                } else {
                    ForEach(tasks) { task in
                        TaskCardView(task: task)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .padding(.horizontal, 8)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteTask(task)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    withAnimation {
                                        toggleTaskCompletion(task)
                                    }
                                } label: {
                                    Label(task.isCompleted ? "Mark Incomplete" : "Complete", 
                                          systemImage: task.isCompleted ? "circle" : "checkmark.circle")
                                        .tint(.green)
                                }
                            }
                            .onTapGesture {
                                selectedTaskId = task.id?.uuidString
                            }
                    }
                }
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
        }
        .searchable(text: $searchText, prompt: "Search tasks")
        .onChange(of: searchText) { _ in
            updateFetchRequest()
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
                TaskFormView(mode: .add, onSave: {
                    viewContext.refreshAllObjects()
                })
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedTaskId) { taskId in
            NavigationStack {
                TaskFormView(mode: .edit(taskId), onSave: {
                    viewContext.refreshAllObjects()
                })
            }
            .presentationDetents([.medium, .large])
            .onDisappear {
                selectedTaskId = nil
            }
        }
        .onAppear {
            updateFetchRequest()
        }
        .onChange(of: completedTasksVisible) { _ in
            updateFetchRequest()
        }
    }
    
    // MARK: - Private Methods
    
    private func updateFetchRequest() {
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
            let dateRange = DateUtils.getTodayDateRange()
            
            // Get tasks where the due date is today
            let dueTodayPredicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@", 
                                               dateRange.startOfDay as NSDate, 
                                               dateRange.startOfTomorrow as NSDate)
            
            predicates.append(dueTodayPredicate)
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
        
        // Create a compound predicate if we have any predicates
        let predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        // Update only the predicate, keeping the sort descriptors the same
        tasks.nsPredicate = predicate
    }
    
    private func deleteTask(_ task: Task) {
        withAnimation {
            dataController.delete(task)
            viewContext.refreshAllObjects()
        }
    }
    
    private func toggleTaskCompletion(_ task: Task) {
        guard let id = task.id else { return }
        
        withAnimation {
            dataController.toggleTaskCompletion(id: id)
            viewContext.refreshAllObjects()
        }
    }
}