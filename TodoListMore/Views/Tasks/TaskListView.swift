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
    
    // Edit mode states
    @State private var isEditMode = false
    @State private var selectedTaskIds = Set<UUID>()
    
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
                // Hide filter when in edit mode
                if !isEditMode {
                    SegmentedFilterView(selectedFilter: $selectedFilter)
                        .padding(.horizontal, 16)
                        .padding(.top, 0)
                        .padding(.bottom, 0)
                        .background(Color.white)
                        .onChange(of: selectedFilter) { _ in
                            updateFetchRequest()
                        }
                } else {
                    // iOS-native edit mode header
                    VStack(spacing: 0) {
                        // Keeping the top divider as it's needed to separate the edit mode header from navigation bar
                        Divider()
                        
                        HStack {
                            // Left action: Select All / Deselect All
                            Button(action: {
                                withAnimation {
                                    if selectedTaskIds.count == tasks.count && !tasks.isEmpty {
                                        selectedTaskIds.removeAll()
                                    } else {
                                        selectedTaskIds = Set(tasks.compactMap { $0.id })
                                    }
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: selectedTaskIds.count == tasks.count && !tasks.isEmpty ? "minus.square" : "checkmark.square")
                                        .font(.system(size: 15, weight: .medium))
                                    Text(selectedTaskIds.count == tasks.count && !tasks.isEmpty ? "Deselect All" : "Select All")
                                        .font(.system(size: 15))
                                }
                                .foregroundColor(Color(hex: "#5D4EFF"))
                            }
                            .disabled(tasks.isEmpty)
                            
                            Spacer()
                            
                            // Selected count indicator
                            if selectedTaskIds.count > 0 {
                                Text("\(selectedTaskIds.count) item\(selectedTaskIds.count > 1 ? "s" : "") selected")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Delete action
                            Button(action: {
                                deleteSelectedTasks()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 15, weight: .medium))
                                    Text("Delete")
                                        .font(.system(size: 15))
                                }
                                .foregroundColor(selectedTaskIds.isEmpty ? .gray : .red)
                            }
                            .disabled(selectedTaskIds.isEmpty)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        // Removed the bottom divider that was causing an unwanted line
                    }
                    .background(Color.white)
                }
                
                // List with swipe actions (replaces ScrollView+VStack)
                List {
                    if tasks.isEmpty {
                        EmptyTaskView(onAddTask: { 
                            // Switch to the appropriate tab before showing the add task form
                            // to ensure the new task will be visible after creation
                            switchToAppropriateTabForNewTask()
                            showingAddTask = true 
                        })
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.white)
                    } else {
                        // Tasks list with swipe actions
                        ForEach(tasks) { task in
                            ZStack {
                                // Task card with iOS-native style in edit mode
                                TaskCardView(task: task)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                    // Standard iOS behavior - no scaling effects
                                    .opacity(selectedTaskIds.contains(task.id ?? UUID()) ? 1.0 : 1.0)
                                
                                // Modified card appearance in edit mode - iOS-style selection
                                if isEditMode, let taskId = task.id {
                                    // iOS-style checkmark at trailing edge (right side)
                                    HStack {
                                        Spacer()
                                        
                                        ZStack {
                                            // Selection circle
                                            Circle()
                                                .fill(selectedTaskIds.contains(taskId) ? 
                                                      Color(hex: "#5D4EFF") : 
                                                      Color(UIColor.systemFill))
                                                .frame(width: 28, height: 28)
                                            
                                            // Checkmark or empty
                                            if selectedTaskIds.contains(taskId) {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .padding(.trailing, 20)
                                        .padding(.leading, 8)
                                    }
                                    
                                    // iOS selection overlay (gray background for selected items)
                                    if selectedTaskIds.contains(taskId) {
                                        Color(UIColor.systemGray5)
                                            .opacity(0.35)
                                            .cornerRadius(10)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                            .contextMenu {
                                if !isEditMode {
                                    Button {
                                        withAnimation {
                                            if let id = task.id {
                                                dataController.toggleTaskCompletion(id: id)
                                                viewContext.refreshAllObjects()
                                            }
                                        }
                                    } label: {
                                        Label(task.isCompleted ? "Mark Incomplete" : "Mark Complete", 
                                              systemImage: task.isCompleted ? "circle" : "checkmark.circle.fill")
                                    }
                                    
                                    Button(role: .destructive) {
                                        deleteTask(task)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .onTapGesture {
                                if isEditMode, let taskId = task.id {
                                    withAnimation(.spring(dampingFraction: 0.7)) {
                                        if selectedTaskIds.contains(taskId) {
                                            selectedTaskIds.remove(taskId)
                                        } else {
                                            selectedTaskIds.insert(taskId)
                                        }
                                    }
                                } else if !isEditMode {
                                    selectedTaskId = task.id?.uuidString
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                // Right swipe - Delete
                                Button(role: .destructive) {
                                    deleteTask(task)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                // Left swipe - Toggle completion
                                Button {
                                    if let id = task.id {
                                        withAnimation {
                                            dataController.toggleTaskCompletion(id: id)
                                            viewContext.refreshAllObjects()
                                        }
                                    }
                                } label: {
                                    Label(
                                        task.isCompleted ? "Incomplete" : "Complete", 
                                        systemImage: task.isCompleted ? "circle" : "checkmark.circle.fill"
                                    )
                                }
                                .tint(task.isCompleted ? .gray : Color(hex: "#5D4EFF"))
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.white)
                        }
                        
                        // Add spacer at bottom for floating button
                        Color.clear
                            .frame(height: 76)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.white)
                    }
                }
                .listStyle(.plain)
                .background(Color.white)
            }
            
            // Floating action button (positioned with its own container)
            // Hide when in edit mode
            if !isEditMode {
                FloatingAddButton {
                    // Switch to the appropriate tab before showing the add task form
                    switchToAppropriateTabForNewTask()
                    showingAddTask = true
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search tasks")
        .onChange(of: searchText) { _ in
            updateFetchRequest()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation {
                        // Toggle edit mode and clear selections when exiting
                        isEditMode.toggle()
                        if !isEditMode {
                            selectedTaskIds.removeAll()
                        }
                    }
                }) {
                    if isEditMode {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(hex: "#5D4EFF"))
                    } else {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#5D4EFF"))
                    }
                }
                .disabled(tasks.isEmpty)
            }
        }
        .background(Color.white)
        .sheet(isPresented: $showingAddTask) {
            NavigationStack {
                TaskFormView(mode: .add, onSave: {
                    viewContext.refreshAllObjects()
                    
                    // Switch to the appropriate tab after adding a new task
                    // to ensure the new task will be visible after creation
                    switchToAppropriateTabForNewTask()
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
        .onReceive(NotificationCenter.default.publisher(for: .dataDidChange)) { _ in
            // Refresh data when category or other data changes
            DispatchQueue.main.async {
                viewContext.refreshAllObjects()
                updateFetchRequest()
            }
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
                
                // Removed the Divider() that was causing the unwanted line
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
                    
                    // Indicator line - only visible when selected
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(accentColor)
                                .frame(height: 2)
                                .frame(width: 40)
                                .matchedGeometryEffect(id: "underline", in: namespace)
                        } else {
                            // Keeping this empty spacer for proper alignment
                            Color.clear
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
    
    // Determine if a new task would be visible in the current filter tab
    private func isNewTaskVisibleInCurrentTab() -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .active:
            return true // New tasks are always active
        case .completed:
            return false // New tasks are never completed
        case .today:
            // New tasks are visible in Today tab only if due date is set to today
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            return false // Default to false since we can't predict if user will set due date to today
        case .upcoming:
            return false // Default to false since we can't predict if user will set future due date
        }
    }
    
    // Switch to appropriate tab for new task if current tab wouldn't show it
    private func switchToAppropriateTabForNewTask() {
        if !isNewTaskVisibleInCurrentTab() {
            selectedFilter = .all
        }
    }
    
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
    
    // Custom edit mode functions
    
    private func deleteSelectedTasks() {
        withAnimation(.spring(dampingFraction: 0.7)) {
            // Find all tasks with matching IDs and delete them
            for taskId in selectedTaskIds {
                if let taskToDelete = tasks.first(where: { $0.id == taskId }) {
                    deleteTask(taskToDelete)
                }
            }
            
            // Clear selection after deletion
            selectedTaskIds.removeAll()
            
            // Exit edit mode if there are no more tasks
            if tasks.isEmpty {
                isEditMode = false
            }
        }
    }
}