//
//  TaskCardView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 24/03/25.
//

import SwiftUI
import CoreData

struct TaskCardView: View {
    let task: Task
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dataController: DataController
    
    // Flag to indicate if this card should be highlighted
    var isHighlighted: Bool = false
    
    var body: some View {
        // Get task properties directly using the entity properties
        let isCompleted = task.isCompleted
        let title = task.title ?? "Untitled Task"
        let description = task.taskDescription ?? ""
        let priority = task.priority
        let dueDate = task.dueDate
        let dateCreated = task.dateCreated
        
        // Get gradient based on priority
        let gradientColors = TaskStyleUtils.priorityGradient(priority: priority)
        
        // Card with shadow and border
        ZStack {
            // Background based on color scheme
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), 
                        radius: 5, x: 0, y: 2)
                        
            // Top gradient line for priority - only shown when not highlighted
            VStack(spacing: 0) {
                // Hide priority bar when highlighted
                if !isHighlighted {
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: gradientColors),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(height: 4)
                        .cornerRadius(14, corners: [.topLeft, .topRight])
                }
                
                Spacer()
            }
            
            // Highlight overlay for notification-tapped task - now on top of everything
            if isHighlighted {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.red, lineWidth: 4)
                    .shadow(color: Color.red.opacity(0.5), radius: 6, x: 0, y: 0)
            }
            
            // Content with reduced spacing - simplified structure
            VStack(alignment: .leading, spacing: 0) {
                // Header with title and status
                TaskCardHeaderView(
                    task: task,
                    isCompleted: isCompleted,
                    title: title,
                    description: description,
                    dueDate: dueDate,
                    priority: priority,
                    gradientColors: gradientColors
                )
                .padding(.top, 2) // Minimal top padding
                
                // Small fixed spacing
                Color.clear.frame(height: 4)
                
                // Footer with metadata
                TaskCardFooterView(
                    dueDate: dueDate,
                    dateCreated: dateCreated,
                    task: task
                )
                .padding(.horizontal, 16) // Add horizontal padding here
                .padding(.bottom, 2) // Minimal bottom padding
            }
            
            // Content layer without bell icon
            
            // Bell icon for notification - positioned as the last item to ensure it's on top
            if isHighlighted {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "bell.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.red)
                                    .shadow(color: Color.red.opacity(0.5), radius: 4, x: 0, y: 0)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1.5)
                            )
                            .padding(8)
                    }
                    Spacer()
                }
                .zIndex(999) // Ensure it's on top of everything
            }
        }
        .frame(height: description.isEmpty ? AppTheme.UI.cardHeight : AppTheme.UI.cardHeightWithDescription)
        .padding(.horizontal, 4)
        .padding(.vertical, 0)
        .contentShape(Rectangle())
        // Styling for completed tasks
        .opacity(isCompleted ? 0.85 : 1.0)
        // Background highlight for notification
        .background(isHighlighted ? Color.red.opacity(0.2) : Color.clear)
        // Animation for highlight
        .scaleEffect(isHighlighted ? 1.03 : 1.0)
        .animation(isHighlighted ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: isHighlighted)
    }
}

struct TaskCardHeaderView: View {
    let task: Task
    let isCompleted: Bool
    let title: String
    let description: String
    let dueDate: Date?
    let priority: Int16
    let gradientColors: [Color]
    
    @EnvironmentObject private var dataController: DataController
    
    var body: some View {
        // Get the category color
        let categoryColor = task.category != nil ? 
            Color(hex: task.category?.colorHex ?? AppTheme.accentColor.hex) : 
            AppTheme.accentColor
            
        HStack(alignment: .center, spacing: 14) {
            // Checkbox with animated press effect
            Button(action: {
                if let id = task.id {
                    // Call the toggle task method with animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dataController.toggleTaskCompletion(id: id)
                        // Force refresh to ensure UI updates
                        task.managedObjectContext?.refresh(task, mergeChanges: true)
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
                if let dueDate = dueDate, DateUtils.isDueSoon(dueDate) && !isCompleted {
                    Text(DateUtils.formatDueDate(dueDate))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DateUtils.isOverdue(dueDate) ? .red : .orange)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 0)
        
        // Show a snippet of the description if available
        if !description.isEmpty {
            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(3) // Allow up to 3 lines for description
                .padding(.vertical, 4) // Equal padding top and bottom
                .padding(.horizontal, 16)
                .padding(.leading, 46) // Align with title text
        }
    }
}

struct TaskCardFooterView: View {
    let dueDate: Date?
    let dateCreated: Date?
    let task: Task
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Create formatter outside the view body
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d h:mma" // Compact AM/PM format like "4/1 3:30PM"
        return formatter
    }()
    
    var body: some View {
        // Simplified footer with horizontal layout
        HStack(alignment: .center, spacing: 4) {
            // Combined due date and time ago in a single container
            HStack(spacing: 8) {
                // Due date badge - compact format
                if let dueDate = dueDate {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(dateFormatter.string(from: dueDate))
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : Color.secondary)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(colorScheme == .dark ? Color.secondary.opacity(0.2) : Color.secondary.opacity(0.08))
                    .cornerRadius(6)
                }
                
                // Time ago badge right next to due date
                if let dateCreated = dateCreated {
                    Text(DateUtils.timeAgo(from: dateCreated))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Category at the end
            TaskCategoryView(task: task)
        }
    }
}

