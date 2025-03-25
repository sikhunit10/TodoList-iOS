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
        ZStack {
            VStack(spacing: 0) {
                // Modern Filter Selector
                // Custom animated segment control with nice visuals
                SegmentedFilterView(selectedFilter: $selectedFilter)
                    .padding(.horizontal, 16)
                    .padding(.top, 0)
                    .padding(.bottom, 0)
                    .background(Color(UIColor.systemBackground))
                    .onChange(of: selectedFilter) { _ in
                        updateFetchRequest()
                    }
                
                // Task List with improved spacing
                List {
                    if tasks.isEmpty {
                        EmptyTaskView(onAddTask: { showingAddTask = true })
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    } else {
                        ForEach(tasks) { task in
                            TaskCardView(task: task)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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
                                              systemImage: task.isCompleted ? "circle" : "checkmark.circle.fill")
                                            .tint(.green)
                                    }
                                }
                                .onTapGesture {
                                    selectedTaskId = task.id?.uuidString
                                }
                        }
                        
                        // Add consistent space at the bottom
                        Spacer()
                            .frame(height: 80)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .background(Color(UIColor.systemBackground))
            }
            
            // Floating action button (positioned with its own container)
            FloatingAddButton {
                showingAddTask = true
            }
        }
        .searchable(text: $searchText, prompt: "Search tasks")
        .onChange(of: searchText) { _ in
            updateFetchRequest()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .background(Color(UIColor.systemBackground))
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
    
    // Custom Segmented Control (Simplified)
    struct SegmentedFilterView: View {
        @Binding var selectedFilter: TaskFilter
        @Environment(\.colorScheme) private var colorScheme
        @Namespace private var namespace
        
        private let accentColor = Color(hex: "#5D4EFF")
        
        var body: some View {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(TaskFilter.allCases) { filter in
                            FilterButton(
                                filter: filter,
                                isSelected: selectedFilter == filter,
                                accentColor: accentColor,
                                namespace: namespace,
                                action: {
                                    withAnimation(.spring(dampingFraction: 0.7)) {
                                        selectedFilter = filter
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
                
                Divider()
            }
        }
    }
    
    // Extracted subview to simplify the SegmentedFilterView
    struct FilterButton: View {
        let filter: TaskFilter
        let isSelected: Bool
        let accentColor: Color
        var namespace: Namespace.ID
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 4) {
                    Text(filter.name)
                        .font(.system(size: 14))
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(isSelected ? accentColor : .gray)
                        .fixedSize(horizontal: true, vertical: false)
                    
                    // Indicator line
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(accentColor)
                                .frame(height: 2)
                                .frame(width: 40)
                                .matchedGeometryEffect(id: "underline", in: namespace)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 2)
                                .frame(width: 40)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // Floating Action Button
    struct FloatingAddButton: View {
        var action: () -> Void
        @Environment(\.colorScheme) private var colorScheme
        
        var body: some View {
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button(action: action) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#5D4EFF"))
                                .frame(width: 62, height: 62)
                                .shadow(color: Color(hex: "#5D4EFF").opacity(colorScheme == .dark ? 0.3 : 0.4), 
                                        radius: 8, x: 0, y: 4)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.trailing, 24)
                    .padding(.bottom, 20)
                }
            }
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