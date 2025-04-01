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
    @State private var animateHighlight = false
    @AppStorage("completedTasksVisible") private var completedTasksVisible = true
    
    // Task to highlight (from notification) - now using a binding to get live updates
    @Binding var highlightedTaskId: UUID?
    
    // Print the ID for debugging
    init(highlightedTaskId: Binding<UUID?>) {
        self._highlightedTaskId = highlightedTaskId
        print("TaskListView initialized with highlightedTaskId: \(String(describing: highlightedTaskId.wrappedValue))")
    }
    
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
                // Filter header
                filterHeader
                
                // Task list
                taskList
            }
            
            // Floating action button
            if !isEditMode {
                FloatingAddButton {
                    switchToAppropriateTabForNewTask()
                    showingAddTask = true
                }
            }
        }
        .toolbarBackground(.white, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search tasks")
        .onChange(of: searchText) { _ in
            updateFetchRequest()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                editButton
            }
        }
        .background(Color.white)
        .sheet(isPresented: $showingAddTask) {
            NavigationStack {
                TaskFormView(mode: .add, onSave: { switchToAppropriateTabForNewTask() })
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedTaskId) { taskId in
            NavigationStack {
                TaskFormView(mode: .edit(taskId), onSave: {})
            }
            .presentationDetents([.medium, .large])
            .onDisappear {
                selectedTaskId = nil
            }
        }
        .onAppear {
            updateFetchRequest()
            if highlightedTaskId != nil {
                showTaskForHighlighting()
            }
        }
        .onChange(of: completedTasksVisible) { _ in updateFetchRequest() }
        .onChange(of: highlightedTaskId) { _ in 
            if highlightedTaskId != nil {
                showTaskForHighlighting()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tasksDidChange)) { notification in
            DispatchQueue.main.async {
                if let taskId = notification.userInfo?["taskId"] as? UUID,
                   let task = tasks.first(where: { $0.id == taskId }) {
                    viewContext.refresh(task, mergeChanges: true)
                } else if notification.userInfo?["batchDelete"] as? Bool == true {
                    updateFetchRequest()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .categoriesDidChange)) { _ in
            DispatchQueue.main.async { updateFetchRequest() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataDidChange)) { _ in
            DispatchQueue.main.async { updateFetchRequest() }
        }
    }
    
    // MARK: - View Components
    
    // Filter header
    var filterHeader: some View {
        Group {
            if !isEditMode {
                // Regular filter tabs
                SegmentedFilterView(selectedFilter: $selectedFilter)
                    .padding(.top, 0)
                    .padding(.bottom, 0)
                    .background(Color.white)
                    .onChange(of: selectedFilter) { _ in
                        updateFetchRequest()
                    }
            } else {
                // Edit mode header
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack {
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
                        
                        if selectedTaskIds.count > 0 {
                            Text("\(selectedTaskIds.count) item\(selectedTaskIds.count > 1 ? "s" : "") selected")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
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
                }
                .background(Color.white)
            }
        }
    }
    
    // Task list
    var taskList: some View {
        List {
            if tasks.isEmpty {
                emptyTaskView
            } else {
                // Tasks
                ForEach(tasks) { task in
                    taskRow(task: task)
                }
                
                // Bottom spacer
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
    
    // Empty state view
    var emptyTaskView: some View {
        EmptyTaskView(onAddTask: { 
            switchToAppropriateTabForNewTask()
            showingAddTask = true 
        })
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.white)
    }
    
    // Edit button
    var editButton: some View {
        Button(action: {
            withAnimation {
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
    
    // Individual task row
    func taskRow(task: Task) -> some View {
        ZStack {
            // Base task card with highlighting directly in card
            TaskCardView(task: task, isHighlighted: task.id == highlightedTaskId && animateHighlight)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            
            
            // Edit mode overlay
            if isEditMode, let taskId = task.id {
                HStack {
                    Spacer()
                    // Selection circle
                    ZStack {
                        Circle()
                            .fill(selectedTaskIds.contains(taskId) ? 
                                  Color(hex: "#5D4EFF") : 
                                  Color(UIColor.systemFill))
                            .frame(width: 28, height: 28)
                        
                        // Checkmark
                        if selectedTaskIds.contains(taskId) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.leading, 8)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditMode, let taskId = task.id {
                withAnimation {
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
        .contextMenu {
            if !isEditMode {
                Button {
                    withAnimation {
                        if let id = task.id {
                            dataController.toggleTaskCompletion(id: id)
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
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteTask(task)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                if let id = task.id {
                    withAnimation {
                        dataController.toggleTaskCompletion(id: id)
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
    
    // MARK: - Methods
    
    // Show task highlighting when tapped from notification
    private func showTaskForHighlighting() {
        guard let taskId = highlightedTaskId else { 
            print("Cannot highlight task: highlightedTaskId is nil")
            return 
        }
        
        print("Showing highlight for task: \(taskId)")
        
        // Reset filter to show all tasks first to ensure task is visible
        DispatchQueue.main.async {
            // Reset filter and search to ensure task is visible
            self.selectedFilter = .all
            self.searchText = ""
            self.updateFetchRequest()
            
            // Force refresh the view context to ensure we have latest data
            self.viewContext.refreshAllObjects()
            
            // Ensure we have the task in our list
            let taskExists = self.tasks.contains { $0.id == taskId }
            print("Task exists in list: \(taskExists)")
            
            // Start highlighting with a slight delay to ensure UI has updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.animateHighlight = true
                    print("Animation highlight turned ON")
                }
                
                // Schedule highlight off after 4 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.animateHighlight = false
                        print("Animation highlight turned OFF")
                    }
                }
            }
        }
    }
    
    // Check if task would be visible in current filter
    private func isNewTaskVisibleInCurrentTab() -> Bool {
        switch selectedFilter {
        case .all: return true
        case .active: return true
        case .completed: return false
        case .today, .upcoming: return false
        }
    }
    
    // Switch to appropriate tab for new task
    private func switchToAppropriateTabForNewTask() {
        if !isNewTaskVisibleInCurrentTab() {
            selectedFilter = .all
        }
    }
    
    // Update fetch request with current filters
    private func updateFetchRequest() {
        var predicates: [NSPredicate] = []
        
        // Search filter
        if !searchText.isEmpty {
            let searchPredicate = NSPredicate(format: "title CONTAINS[cd] %@ OR taskDescription CONTAINS[cd] %@", 
                                             searchText, searchText)
            predicates.append(searchPredicate)
        }
        
        // Status filter
        switch selectedFilter {
        case .active:
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: false)))
        case .completed:
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: true)))
        case .today:
            let dateRange = DateUtils.getTodayDateRange()
            predicates.append(NSPredicate(format: "dueDate >= %@ AND dueDate < %@", 
                                         dateRange.startOfDay as NSDate, 
                                         dateRange.startOfTomorrow as NSDate))
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: false)))
        case .upcoming:
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            predicates.append(NSPredicate(format: "dueDate > %@ AND isCompleted == %@", startOfDay as NSDate, NSNumber(value: false)))
        case .all:
            if !completedTasksVisible {
                predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: false)))
            }
        }
        
        // Apply predicates
        let predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        tasks.nsPredicate = predicate
    }
    
    // Delete a task
    private func deleteTask(_ task: Task) {
        withAnimation {
            dataController.delete(task)
        }
    }
    
    // Delete selected tasks
    private func deleteSelectedTasks() {
        withAnimation {
            for taskId in selectedTaskIds {
                if let taskToDelete = tasks.first(where: { $0.id == taskId }) {
                    deleteTask(taskToDelete)
                }
            }
            selectedTaskIds.removeAll()
            
            if tasks.isEmpty {
                isEditMode = false
            }
        }
    }
}

// MARK: - SegmentedFilterView

struct SegmentedFilterView: View {
    @Binding var selectedFilter: TaskFilter
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var namespace
    
    private let accentColor = AppTheme.accentColor
    
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
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity)
            
            Divider().opacity(0.5)
        }
    }
}

// MARK: - FilterButton

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
                
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accentColor)
                            .frame(height: 2)
                            .frame(width: AppTheme.UI.filterIndicatorWidth)
                            .matchedGeometryEffect(id: "underline", in: namespace)
                    } else {
                        Color.clear
                            .frame(height: 2)
                            .frame(width: AppTheme.UI.filterIndicatorWidth)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FloatingAddButton

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
                            .fill(AppTheme.accentColor)
                            .frame(width: AppTheme.UI.floatingButtonSize, height: AppTheme.UI.floatingButtonSize)
                            .shadow(color: AppTheme.accentColor.opacity(colorScheme == .dark ? 0.3 : 0.4), 
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