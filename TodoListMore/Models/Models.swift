//
//  Models.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import Foundation
import CoreData
import SwiftUI
import UserNotifications

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
    
    var reminderTypeEnum: ReminderType {
        // Default to none if reminder support isn't available
        if !DataController.shared.hasReminderSupport {
            return .none
        }
        
        // Safe access using try/catch to avoid exceptions
        var reminderTypeValue: Int16 = 0
        
        do {
            if let value = try self.primitiveValue(forKey: "reminderType") as? Int16 {
                reminderTypeValue = value
            }
        } catch {
            // If there's an error, the key likely doesn't exist
            return .none
        }
        
        return ReminderType(rawValue: reminderTypeValue) ?? .none
    }
    
    var formattedDueDate: String {
        guard let dueDate = dueDate else { return "No due date" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short // Include time
        return formatter.string(from: dueDate)
    }
    
    // Helper to manage reminders
    func scheduleReminder() {
        guard let id = id, let dueDate = dueDate else { return }
        
        // Always try to schedule reminders
        // (No check for hasReminderSupport)
        
        let reminderType = self.reminderTypeEnum
        if reminderType == .none {
            // Remove any existing reminders
            NotificationManager.shared.removeTaskReminders(taskId: id)
            return
        }
        
        let title = self.safeTitle
        let description = self.safeDescription
        // We now use the task's description as body in case we need to display it
        // The actual body text shown in notification is now formatted in NotificationManager
        let body = description
        
        // Schedule the reminder
        // Get the reminder type value directly as Int16 for safety
        var reminderTypeValue: Int16 = 0
        
        // Safe access using KVC
        do {
            if let value = self.value(forKey: "reminderType") as? Int16 {
                reminderTypeValue = value
            }
        } catch {
            // If there's an error accessing reminderType, use default value
            print("Error accessing reminderType: \(error.localizedDescription)")
        }
        
        // Get the custom reminder time if it exists
        var customTime: Double? = nil
        
        // Safe access to avoid crash if property doesn't exist
        do {
            if let value = self.value(forKey: "customReminderTime") as? Double {
                customTime = value
            }
        } catch {
            // Key doesn't exist, just leave as nil
            print("Error accessing customReminderTime: \(error.localizedDescription)")
        }
        
        NotificationManager.shared.scheduleTaskReminder(
            taskId: id,
            title: title,
            body: body,
            dueDate: dueDate,
            reminderType: reminderTypeValue, // Pass the raw Int16 value
            customTime: customTime
        )
    }
    
    // Remove reminders for this task
    func removeReminders() {
        guard let id = id else { return }
        
        // Always try to remove reminders
        NotificationManager.shared.removeTaskReminders(taskId: id)
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
        // Get color components
        guard let components = self.cgColor?.components, components.count >= 3 else {
            // Default fallback for AppTheme.defaultCategoryColor
            return "#007AFF"
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
    }
}
