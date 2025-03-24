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
    var taskTitle: String {
        return title ?? "Untitled Task"
    }
    
    var taskDescriptionText: String {
        return self.taskDescription ?? ""
    }
    
    var taskDueDate: Date? {
        return dueDate
    }
    
    var taskPriority: TaskPriority {
        return TaskPriority(rawValue: priority) ?? .medium
    }
    
    var taskCategory: Category? {
        return category
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
    var categoryName: String {
        return name ?? "Uncategorized"
    }
    
    var categoryColorHex: String {
        return colorHex ?? "#007AFF"
    }
    
    var categoryTasks: [Task] {
        let set = tasks as? Set<Task> ?? []
        return Array(set)
    }
}