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
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } else {
                    ForEach(tasks) { task in
                        TaskRow(task: task)
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
                                    // Toggle task completion and force UI update
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
                    // Refresh the task list when a new task is added
                    viewContext.refreshAllObjects()
                })
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedTaskId) { taskId in
            NavigationStack {
                TaskFormView(mode: .edit(taskId), onSave: {
                    // Refresh the task list when task is updated
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
        // First refresh all objects to ensure we have the latest data
        viewContext.refreshAllObjects()
        
        // Build predicates based on current filter and search text
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
            
            // Get the start of today
            let startOfDay = calendar.startOfDay(for: Date())
            
            // Get the start of tomorrow
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            // Get tasks where the due date is today (greater than or equal to start of today,
            // but less than start of tomorrow)
            let dueTodayPredicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@", 
                                               startOfDay as NSDate, 
                                               startOfTomorrow as NSDate)
            
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
            // Ensure UI updates after deletion
            updateFetchRequest()
        }
    }
    
    private func toggleTaskCompletion(_ task: Task) {
        guard let id = task.id else { return }
        
        withAnimation {
            dataController.toggleTaskCompletion(id: id)
            // Ensure UI updates after toggling completion
            updateFetchRequest()
        }
    }
}

// Task row view
struct TaskRow: View {
    let task: Task
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dataController: DataController
    
    var body: some View {
        // Get task properties directly using the entity properties
        let isCompleted = task.isCompleted
        let title = task.title ?? "Untitled Task"
        let description = task.taskDescription ?? ""
        let priority = task.priority
        let dueDate = task.dueDate
        let dateCreated = task.dateCreated
        
        // Category data
        let category = task.category
        let categoryName = category?.name ?? "Uncategorized"
        let colorHex = category?.colorHex ?? "#CCCCCC"
        let categoryColor = Color(hex: colorHex)
        
        // Get gradient based on priority
        let gradientColors = priorityGradient(priority: priority)
        
        // Card with shadow and border
        ZStack {
            // Background based on color scheme
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), 
                        radius: 5, x: 0, y: 2)
            
            // Top gradient line for priority
            VStack(spacing: 0) {
                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 4)
                    .cornerRadius(14, corners: [.topLeft, .topRight])
                
                Spacer()
            }
            
            // Content with proper spacing
            VStack(alignment: .leading, spacing: 0) {
                // Header with title and status
                HStack(alignment: .center, spacing: 14) {
                    // Checkbox with animated press effect
                    Button(action: {
                        if let id = task.id {
                            // Call the toggle task method with animation
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dataController.toggleTaskCompletion(id: id)
                                // Force refresh to ensure UI updates
                                task.managedObjectContext?.refresh(task, mergeChanges: true)
                                task.managedObjectContext?.refreshAllObjects()
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(isCompleted ? categoryColor.opacity(0.15) : Color.clear)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isCompleted ? categoryColor : .secondary)
                                .font(.system(size: 22, weight: .semibold))
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    // Title and due date if near
                    VStack(alignment: .leading, spacing: 2) {
                        // Title
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isCompleted ? .secondary : .primary)
                            .strikethrough(isCompleted)
                            .lineLimit(1)
                        
                        // Due date countdown if within 3 days and not completed
                        if let dueDate = dueDate, isDueSoon(dueDate) && !isCompleted {
                            Text(formatDueDate(dueDate))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isOverdue(dueDate) ? .red : .orange)
                        }
                    }
                    
                    Spacer()
                    
                    // Priority flag
                    if priority > 1 {
                        Image(systemName: priority == 3 ? "flag.fill" : "flag")
                            .foregroundColor(gradientColors[0])
                            .font(.system(size: 15, weight: .semibold))
                            .shadow(color: gradientColors[0].opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
                .padding(.top, 14)
                .padding(.horizontal, 16)
                
                // Show a snippet of the description if available
                if !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.top, 6)
                        .padding(.horizontal, 16)
                        .padding(.leading, 46) // Align with title text
                }
                
                // Custom divider with insets
                Rectangle()
                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray5))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                
                // Footer with metadata
                HStack(spacing: 10) {
                    // Due date chip
                    if let dueDate = dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                            Text(dueDate, style: .date)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : Color.secondary)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .background(colorScheme == .dark ? Color.secondary.opacity(0.2) : Color.secondary.opacity(0.08))
                        .cornerRadius(8)
                    }
                    
                    // Time ago badge
                    if let dateCreated = dateCreated {
                        Text(timeAgo(from: dateCreated))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.secondary.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Category badge
                    HStack(spacing: 5) {
                        // Color dot
                        Circle()
                            .fill(categoryColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: categoryColor.opacity(0.3), radius: 1, x: 0, y: 0)
                        
                        // Category name
                        Text(categoryName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(categoryColor.opacity(0.8))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(categoryColor.opacity(0.12))
                            .shadow(color: categoryColor.opacity(0.1), radius: 1, x: 0, y: 1)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .frame(height: description.isEmpty ? 116 : 136)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        // Styling for completed tasks
        .opacity(isCompleted ? 0.85 : 1.0)
        // Slight scale effect on completed items
        .scaleEffect(isCompleted ? 0.98 : 1.0)
        // Add subtle animation to state changes
        .animation(.easeInOut(duration: 0.2), value: isCompleted)
    }
    
    // MARK: - Helper Methods
    
    // Returns a gradient for the priority indicator
    private func priorityGradient(priority: Int16) -> [Color] {
        switch priority {
        case 1:
            return [Color.blue, Color.blue.opacity(0.7)]
        case 2:
            return [Color.orange, Color.orange.opacity(0.7)]
        case 3:
            return [Color.red, Color.red.opacity(0.7)]
        default:
            return [Color.blue, Color.blue.opacity(0.7)]
        }
    }
    
    // Returns the priority color
    private func priorityColor(_ priority: Int16) -> Color {
        switch priority {
        case 1: return .blue
        case 2: return .orange
        case 3: return .red
        default: return .blue
        }
    }
    
    // Check if due date is within 3 days
    private func isDueSoon(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: date)
        return components.day != nil && components.day! <= 3
    }
    
    // Check if task is overdue
    private func isOverdue(_ date: Date) -> Bool {
        return date < Date()
    }
    
    // Format due date for countdown
    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // Compare by calendar day, not just numerical difference
        let todayStart = calendar.startOfDay(for: now)
        let dateStart = calendar.startOfDay(for: date)
        let dayDifference = calendar.dateComponents([.day], from: todayStart, to: dateStart).day ?? 0
        
        if dayDifference < 0 {
            return "Overdue"
        } else if dayDifference == 0 {
            return "Due today"
        } else if dayDifference == 1 {
            return "Due tomorrow"
        } else {
            return "Due in \(dayDifference) days"
        }
    }
    
    // Format time ago
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return day == 1 ? "1 day ago" : "\(day) days ago"
        } else if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1 hour ago" : "\(hour) hours ago"
        } else if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1 min ago" : "\(minute) mins ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Custom Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Extension to apply corner radius to specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// Placeholder rows for tasks
struct TaskPlaceholderRow: View {
    let index: Int
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dataController: DataController
    
    private let sampleTitles = ["Complete project proposal", "Buy groceries", "Schedule dentist appointment", "Pay bills", "Call mom"]
    private let sampleDesc = ["Draft a comprehensive proposal for the new client project", "Get milk, eggs, bread and vegetables", "Check available slots for next week", "Pay utilities and credit card", "Ask about weekend plans"]
    private let sampleDates = [Date().addingTimeInterval(86400), Date().addingTimeInterval(172800), Date().addingTimeInterval(345600), Date().addingTimeInterval(432000), Date().addingTimeInterval(518400)]
    private let sampleCategories = ["Work", "Personal", "Shopping", "Health"]
    private let sampleColors = ["#FF6B6B", "#4ECDC4", "#FFE66D", "#1A535C"]
    private let sampleTimeAgo = ["2 days ago", "1 hour ago", "Just now", "3 days ago", "Yesterday"]
    private let sampleDueSoon = ["Due today", "Due tomorrow", "Overdue", "Due in 2 days"]
    
    var body: some View {
        // Card with shadow and border
        ZStack {
            // Background based on color scheme
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), 
                        radius: 5, x: 0, y: 2)
            
            // Top gradient line for priority
            VStack(spacing: 0) {
                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: sampleGradient(index)),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 4)
                    .cornerRadius(14, corners: [.topLeft, .topRight])
                
                Spacer()
            }
            
            // Content with proper spacing
            VStack(alignment: .leading, spacing: 0) {
                // Header with title and status
                HStack(alignment: .center, spacing: 14) {
                    // Checkbox
                    let colorIndex = index % sampleColors.count
                    let isCompleted = index % 3 == 0
                    ZStack {
                        Circle()
                            .fill(isCompleted ? Color(hex: sampleColors[colorIndex]).opacity(0.15) : Color.clear)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isCompleted ? Color(hex: sampleColors[colorIndex]) : .secondary)
                            .font(.system(size: 22, weight: .semibold))
                    }
                    
                    // Title and due date if near
                    VStack(alignment: .leading, spacing: 2) {
                        // Title
                        Text(sampleTitles[index % sampleTitles.count])
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isCompleted ? .secondary : .primary)
                            .strikethrough(isCompleted)
                            .lineLimit(1)
                        
                        // Due date countdown if within 3 days
                        if index % 5 <= 3 {
                            Text(sampleDueSoon[index % sampleDueSoon.count])
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(index % sampleDueSoon.count == 2 ? .red : .orange)
                        }
                    }
                    
                    Spacer()
                    
                    // Priority flag
                    if index % 3 > 0 {
                        Image(systemName: index % 3 == 2 ? "flag.fill" : "flag")
                            .foregroundColor(sampleGradient(index)[0])
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .padding(.top, 14)
                .padding(.horizontal, 16)
                .redacted(reason: .placeholder)
                
                // Show a snippet of the description if available
                if index % 2 == 0 {  // Only show for some cards
                    Text(sampleDesc[index % sampleDesc.count])
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.top, 6)
                        .padding(.horizontal, 16)
                        .padding(.leading, 46) // Align with title text
                        .redacted(reason: .placeholder)
                }
                
                // Custom divider with insets
                Rectangle()
                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray5))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                
                // Footer with metadata
                HStack(spacing: 10) {
                    // Due date chip
                    if index % 4 != 3 {  // Skip for some to show variety
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                            Text(sampleDates[index % sampleDates.count], style: .date)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : Color.secondary)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .background(colorScheme == .dark ? Color.secondary.opacity(0.2) : Color.secondary.opacity(0.08))
                        .cornerRadius(8)
                    }
                    
                    // Time ago badge
                    Text(sampleTimeAgo[index % sampleTimeAgo.count])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.secondary.opacity(0.8))
                    
                    Spacer()
                    
                    // Category badge
                    let colorIndex = index % sampleColors.count
                    let categoryColor = Color(hex: sampleColors[colorIndex])
                    
                    HStack(spacing: 5) {
                        // Color dot
                        Circle()
                            .fill(categoryColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: categoryColor.opacity(0.3), radius: 1, x: 0, y: 0)
                        
                        // Category name
                        Text(sampleCategories[colorIndex])
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(categoryColor.opacity(0.8))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(categoryColor.opacity(0.12))
                            .shadow(color: categoryColor.opacity(0.1), radius: 1, x: 0, y: 1)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .redacted(reason: .placeholder)
            }
        }
        .frame(height: index % 2 == 0 ? 136 : 116)  // Vary height based on description
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        // Styling for completed tasks
        .opacity(index % 3 == 0 ? 0.85 : 1.0)
        // Slight scale effect on completed items
        .scaleEffect(index % 3 == 0 ? 0.98 : 1.0)
    }
    
    // Helper methods
    private func sampleGradient(_ index: Int) -> [Color] {
        switch index % 3 {
        case 0:
            return [Color.blue, Color.blue.opacity(0.7)]
        case 1:
            return [Color.orange, Color.orange.opacity(0.7)]
        case 2:
            return [Color.red, Color.red.opacity(0.7)]
        default:
            return [Color.blue, Color.blue.opacity(0.7)]
        }
    }
}

// Extension to make String identifiable for the sheet
extension String: Identifiable {
    public var id: String { self }
}