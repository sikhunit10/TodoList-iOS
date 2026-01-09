//
//  TaskListView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import CoreData
import UIKit
import AmplitudeSwift

struct TaskListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataController: DataController
    
    @State private var showingAddTask = false
    @State private var searchText = ""
    @State private var selectedFilter: TaskFilter = .all
    @State private var selectedTaskId: String? = nil
    @State private var animateHighlight = false
    @State private var initialLoadComplete = false
    @State private var wasInBackground = false
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
    
    // Template state
    @State private var showingTemplateLibrary = false
    
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
    
    // Computed property to filter tasks based on selected filter and completion toggle
    private var filteredTasks: [Task] {
        let tasksArray = Array(tasks)
        
        // Explicitly handle each filter, including priority
        switch selectedFilter {
        case .priority:
            // Show only incomplete tasks sorted by priority descending
            return tasksArray
                .filter { !$0.isCompleted }
                .sorted { $0.priority > $1.priority }
        case .active:
            // Only show incomplete tasks
            return tasksArray.filter { !$0.isCompleted }
        case .completed:
            // Only show completed tasks
            return tasksArray.filter { $0.isCompleted }
        default:
            // 'all' filter respects completedTasksVisible toggle
            if selectedFilter == .all && !completedTasksVisible {
                return tasksArray.filter { !$0.isCompleted }
            }
            // Other filters (today, upcoming) are driven by the fetch request predicate
            return tasksArray
        }
    }
    
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
        .toolbarBackground(AppTheme.appBackground, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search tasks")
        .onChange(of: searchText) { _ in
            updateFetchRequest()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: {
                        showingTemplateLibrary = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accentColor.opacity(0.1))
                                .frame(width: 36, height: 36)

                            Image(systemName: "doc.text")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppTheme.accentColor, AppTheme.accentColorDark],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }

                    editButton
                }
            }
        }
        .background(AppTheme.appBackground)
        .sheet(isPresented: $showingAddTask) {
            NavigationStack {
                TaskFormView(mode: .add, onSave: { switchToAppropriateTabForNewTask() })
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingTemplateLibrary) {
            TemplateLibraryView()
                .environmentObject(dataController)
        }
        .sheet(item: $selectedTaskId) { taskId in
            NavigationStack {
                TaskFormView(mode: .edit(taskId), onSave: {})
            }
            .presentationDetents([.medium, .large])
            .onDisappear {
                selectedTaskId = nil
                // Force update fetch request to ensure proper filtering when form is closed
                updateFetchRequest()
            }
        }
        .onAppear {
            updateFetchRequest()
            
            // Check for active tasks and select the Active tab by default on initial load
            if !initialLoadComplete {
                checkForActiveTasks()
                initialLoadComplete = true
            }
            
            if let taskId = highlightedTaskId {
                print("Initial highlight ID detected: \(taskId)")
                // Delay the highlight to ensure view is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showTaskForHighlighting()
                }
            }
        }
        .onChange(of: completedTasksVisible) { _ in updateFetchRequest() }
        .onChange(of: highlightedTaskId) { _ in 
            if let taskId = highlightedTaskId {
                print("New highlighted task ID detected: \(taskId)")
                showTaskForHighlighting()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tasksDidChange)) { notification in
            DispatchQueue.main.async {
                if notification.userInfo?["batchDelete"] as? Bool == true {
                    updateFetchRequest()
                    return
                }
                
                // Check if this is a forced refresh from task completion toggle
                let forceRefresh = notification.userInfo?["forceRefreshFetchRequest"] as? Bool == true
                
                // Always update the fetch request first to maintain filtering consistency
                updateFetchRequest(forceRefreshDates: forceRefresh)
                
                // If a task was marked as completed, force a view context refresh
                if let isCompleted = notification.userInfo?["isCompleted"] as? Bool, isCompleted {
                    viewContext.refreshAllObjects()
                }
                
                // Then refresh individual task if needed
                if let taskId = notification.userInfo?["taskId"] as? UUID,
                   let task = tasks.first(where: { $0.id == taskId }) {
                    viewContext.refresh(task, mergeChanges: true)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .categoriesDidChange)) { _ in
            DispatchQueue.main.async { updateFetchRequest() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataDidChange)) { _ in
            DispatchQueue.main.async { updateFetchRequest() }
        }
        // Handle deep links (e.g. from widgets) for filters
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkReceived)) { notification in
            if let raw = notification.userInfo?["deepLink"] as? String {
                // Switch to appropriate filter in response to deep link
                switch raw {
                case DeepLink.today.rawValue:
                    selectedFilter = .today
                case DeepLink.priority.rawValue:
                    selectedFilter = .priority
                default:
                    break
                }
                // Refresh the fetch request to apply new filter
                updateFetchRequest(forceRefreshDates: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // App is going to background
            wasInBackground = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // App returned to foreground
            if wasInBackground {
                // Preserve current filter but force refresh with updated date ranges
                let currentFilter = selectedFilter
                DispatchQueue.main.async {
                    // Re-apply the filter to ensure consistency
                    selectedFilter = currentFilter
                    // Clear contexts to ensure they use fresh data
                    viewContext.refreshAllObjects()
                    // For date-based filters, always recalculate the date predicates
                    updateFetchRequest(forceRefreshDates: true)
                }
                wasInBackground = false
            }
        }
    }
    
    // MARK: - View Components
    
    // Filter header with modern styling
    var filterHeader: some View {
        Group {
            if !isEditMode {
                // Modern filter tabs
                SegmentedFilterView(selectedFilter: $selectedFilter)
                    .padding(.top, 0)
                    .padding(.bottom, 0)
                    .background(AppTheme.appBackground)
                    .onChange(of: selectedFilter) { _ in
                        // Always use fresh date values when changing filters
                        updateFetchRequest(forceRefreshDates: true)
                    }
            } else {
                // Modern edit mode header
                VStack(spacing: 0) {
                    Divider()
                        .background(AppTheme.borderColor)

                    HStack {
                        Button(action: {
                            withAnimation(AppTheme.UI.springAnimation) {
                                if selectedTaskIds.count == filteredTasks.count && !filteredTasks.isEmpty {
                                    selectedTaskIds.removeAll()
                                } else {
                                    selectedTaskIds = Set(filteredTasks.compactMap { $0.id })
                                }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: selectedTaskIds.count == filteredTasks.count && !filteredTasks.isEmpty ? "minus.square.fill" : "checkmark.square")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(selectedTaskIds.count == filteredTasks.count && !filteredTasks.isEmpty ? "Deselect All" : "Select All")
                                    .font(.system(size: AppTheme.Typography.subheadline, weight: .medium))
                            }
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppTheme.accentColor, AppTheme.accentColorDark],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        }
                        .disabled(filteredTasks.isEmpty)

                        Spacer()

                        if selectedTaskIds.count > 0 {
                            Text("\(selectedTaskIds.count) item\(selectedTaskIds.count > 1 ? "s" : "") selected")
                                .font(.system(size: AppTheme.Typography.subheadline, weight: .medium))
                                .foregroundColor(AppTheme.secondaryText)
                        }

                        Spacer()

                        Button(action: {
                            deleteSelectedTasks()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Delete")
                                    .font(.system(size: AppTheme.Typography.subheadline, weight: .medium))
                            }
                            .foregroundColor(selectedTaskIds.isEmpty ? AppTheme.tertiaryText : AppTheme.errorColor)
                        }
                        .disabled(selectedTaskIds.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(AppTheme.appBackground)
            }
        }
    }
    
    // Task list with modern background
    var taskList: some View {
        List {
            if filteredTasks.isEmpty {
                emptyTaskView
            } else {
                // Tasks
                ForEach(filteredTasks) { task in
                    taskRow(task: task)
                }

                // Bottom spacer
                Color.clear
                    .frame(height: 76)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .background(AppTheme.appBackground)
        .scrollContentBackground(.hidden)
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
        .listRowBackground(Color.clear)
    }
    
    // Edit button with modern styling
    var editButton: some View {
        Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            withAnimation(AppTheme.UI.springAnimation) {
                isEditMode.toggle()
                if !isEditMode {
                    selectedTaskIds.removeAll()
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(
                        isEditMode
                        ? LinearGradient(
                            colors: [AppTheme.successColor, AppTheme.successColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [AppTheme.accentColor.opacity(0.1), AppTheme.accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: isEditMode ? "checkmark" : "square.and.pencil")
                    .font(.system(size: isEditMode ? 17 : 16, weight: .semibold))
                    .foregroundColor(isEditMode ? .white : AppTheme.accentColor)
            }
        }
        .disabled(filteredTasks.isEmpty)
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
                            
                            // Force a UI update
                            DispatchQueue.main.async {
                                // Post notification to force fetch request update
                                NotificationCenter.default.post(
                                    name: .tasksDidChange,
                                    object: nil,
                                    userInfo: ["taskId": id, "forceRefreshFetchRequest": true]
                                )
                                
                                // Refresh all objects to ensure filter is applied correctly
                                viewContext.refreshAllObjects()
                            }
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

                        // Force a UI update for task list filtering
                        DispatchQueue.main.async {
                            // Post notification to force fetch request update
                            NotificationCenter.default.post(
                                name: .tasksDidChange,
                                object: nil,
                                userInfo: ["taskId": id, "forceRefreshFetchRequest": true]
                            )

                            // Refresh all objects to ensure filter is applied
                            viewContext.refreshAllObjects()
                        }
                    }
                }
            } label: {
                Label(
                    task.isCompleted ? "Incomplete" : "Complete",
                    systemImage: task.isCompleted ? "circle" : "checkmark.circle.fill"
                )
            }
            .tint(task.isCompleted ? AppTheme.secondaryText : AppTheme.successColor)
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
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
            
            // Force refresh the view context to ensure we have latest data
            self.viewContext.refreshAllObjects()
            
            // Force update with refreshed date values
            self.updateFetchRequest(forceRefreshDates: true)
            
            // Ensure we have the task in our list
            let taskExists = self.tasks.contains { $0.id == taskId }
            print("Task exists in list: \(taskExists)")
            
            if !taskExists {
                print("Task with ID \(taskId) not found in the list. Checking if it exists in CoreData.")
                // Check if the task exists in CoreData
                let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)
                
                do {
                    let taskCount = try self.viewContext.count(for: fetchRequest)
                    print("CoreData task with ID \(taskId) exists: \(taskCount > 0)")
                    
                    // If task exists but isn't in our filtered list, we need to update our filter
                    if taskCount > 0 {
                        // Force re-fetch
                        self.tasks.nsPredicate = nil
                        self.updateFetchRequest(forceRefreshDates: true)
                    }
                } catch {
                    print("Error checking for task: \(error.localizedDescription)")
                }
            }
            
            // Start highlighting with a slight delay to ensure UI has updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
        case .all:
            return true
        case .active:
            return true
        case .completed:
            return false
        case .today, .upcoming:
            return false
        case .priority:
            // Priority view shows all incomplete tasks (sorted by priority)
            return true
        }
    }
    
    // Switch to appropriate tab for new task
    private func switchToAppropriateTabForNewTask() {
        if !isNewTaskVisibleInCurrentTab() {
            selectedFilter = .all
        }
    }
    
    // Update fetch request with current filters
    private func updateFetchRequest(forceRefreshDates: Bool = false) {
        var predicates: [NSPredicate] = []
        
        // Search filter
        if !searchText.isEmpty {
            let searchPredicate = NSPredicate(format: "title CONTAINS[cd] %@ OR taskDescription CONTAINS[cd] %@", 
                                             searchText, searchText)
            predicates.append(searchPredicate)
        }
        
        // Status filter (including priority)
        switch selectedFilter {
        case .active:
            // Show only incomplete tasks
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: false)))
        case .completed:
            // Show only completed tasks
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: true)))
        case .today:
            // Always get fresh date range to handle app returning from background
            let dateRange = DateUtils.getTodayDateRange()
            predicates.append(NSPredicate(format: "dueDate >= %@ AND dueDate < %@", 
                                         dateRange.startOfDay as NSDate, 
                                         dateRange.startOfTomorrow as NSDate))
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: false)))
        case .upcoming:
            // Always get fresh start of day to handle app returning from background
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            predicates.append(NSPredicate(format: "dueDate > %@", startOfDay as NSDate))
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: false)))
        case .priority:
            // Show only incomplete tasks; sorting by priority happens in filteredTasks
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: false)))
        case .all:
            // 'All' respects completedTasksVisible toggle in filteredTasks
            break
        }
        
        // Apply predicates
        let predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        // Apply predicate immediately
        tasks.nsPredicate = predicate
    }
    
    // Delete a task
    private func deleteTask(_ task: Task) {
        withAnimation {
            // Track task deletion
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.amplitude.track(
                eventType: "task_deleted",
                eventProperties: [
                    "priority": task.priority,
                    "is_completed": task.isCompleted,
                    "has_category": task.category != nil
                ]
            )
            
            dataController.delete(task)
        }
    }
    
    // Delete selected tasks
    private func deleteSelectedTasks() {
        withAnimation {
            // Track bulk deletion
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.amplitude.track(
                eventType: "tasks_bulk_deleted",
                eventProperties: ["count": selectedTaskIds.count]
            )
            
            for taskId in selectedTaskIds {
                if let taskToDelete = filteredTasks.first(where: { $0.id == taskId }) {
                    // Use delete method without tracking individual deletions
                    dataController.delete(taskToDelete)
                }
            }
            selectedTaskIds.removeAll()
            
            if filteredTasks.isEmpty {
                isEditMode = false
            }
        }
    }
    
    // Check if there are active tasks and switch to that tab if they exist
    private func checkForActiveTasks() {
        // Create a fetch request to check for active (incomplete) tasks
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompleted == %@", NSNumber(value: false))
        fetchRequest.fetchLimit = 1 // We only need to know if there are any
        
        do {
            let activeTasks = try viewContext.fetch(fetchRequest)
            // If there are active tasks, switch to the active tab
            if !activeTasks.isEmpty {
                withAnimation {
                    selectedFilter = .active
                    updateFetchRequest() // Update the fetch request to reflect the new filter
                }
            }
        } catch {
            print("Error checking for active tasks: \(error.localizedDescription)")
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
            VStack(spacing: 6) {
                Text(filter.name)
                    .font(.system(
                        size: AppTheme.Typography.subheadline,
                        weight: isSelected ? .bold : .medium
                    ))
                    .foregroundStyle(
                        isSelected
                        ? LinearGradient(
                            colors: [AppTheme.accentColor, AppTheme.accentColorDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            colors: [AppTheme.secondaryText, AppTheme.secondaryText],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .fixedSize(horizontal: true, vertical: false)

                // Modern animated indicator
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.primaryGradientStart, AppTheme.primaryGradientEnd],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 3)
                            .frame(width: AppTheme.UI.filterIndicatorWidth)
                            .shadow(
                                color: AppTheme.accentColor.opacity(0.4),
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                            .matchedGeometryEffect(id: "underline", in: namespace)
                    } else {
                        Color.clear
                            .frame(height: 3)
                            .frame(width: AppTheme.UI.filterIndicatorWidth)
                    }
                }
            }
            .padding(.vertical, 4)
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
                        // Outer glow effect
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        AppTheme.accentColor.opacity(0.3),
                                        AppTheme.accentColor.opacity(0.0)
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 45
                                )
                            )
                            .frame(width: 80, height: 80)

                        // Main button with modern gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppTheme.primaryGradientStart,
                                        AppTheme.primaryGradientEnd
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: AppTheme.UI.floatingButtonSize, height: AppTheme.UI.floatingButtonSize)
                            .shadow(
                                color: AppTheme.accentColor.opacity(0.4),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )

                        // Plus icon with subtle shadow
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.trailing, 24)
                .padding(.bottom, 20)
            }
        }
    }
}
