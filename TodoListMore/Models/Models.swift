//
//  Models.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import Foundation
import CoreData

// MARK: - Task Extensions
extension Task {
    // Convenience methods for Task entity
    var safeTitle: String {
        return title ?? "Untitled Task"
    }
    
    var safeDescription: String {
        return taskDescription ?? ""
    }
    
    var priorityEnum: TaskPriority {
        return TaskPriority(rawValue: priority) ?? .medium
    }
    
    var formattedDueDate: String {
        guard let dueDate = dueDate else { return "No due date" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dueDate)
    }
}

// MARK: - Category Extensions
extension Category {
    // Convenience methods for Category entity
    var safeName: String {
        return name ?? "Uncategorized"
    }
    
    var safeColorHex: String {
        return colorHex ?? AppTheme.defaultCategoryColor.hex
    }
    
    var taskArray: [Task] {
        let set = tasks as? Set<Task> ?? []
        return Array(set)
    }
}

// Helper to get hex from Color
extension Color {
    var hex: String {
        // Default fallback for AppTheme.defaultCategoryColor
        return "#007AFF"
    }
}