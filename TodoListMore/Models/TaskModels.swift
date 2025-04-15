//
//  TaskModels.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import Foundation
import SwiftUI

/// Priority levels for tasks
enum TaskPriority: Int16, CaseIterable, Identifiable {
    case low = 1
    case medium = 2
    case high = 3
    
    var id: Int16 { self.rawValue }
    
    var name: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "flag"
        case .medium: return "flag.fill"
        case .high: return "exclamationmark.flag.fill"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#3478F6" // Blue
        case .medium: return "#FF9F0A" // Orange
        case .high: return "#FF453A" // Red
        }
    }
    
    var themeColor: Color {
        switch self {
        case .low: return AppTheme.taskPriorityLow
        case .medium: return AppTheme.taskPriorityMedium
        case .high: return AppTheme.taskPriorityHigh
        }
    }
    
    // Create from Int value safely
    static func fromInt(_ value: Int) -> TaskPriority {
        guard let priority = TaskPriority(rawValue: Int16(value)) else {
            return .medium // Default to medium if invalid
        }
        return priority
    }
}

/// Filter options for the task list
enum TaskFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case today
    case upcoming
    case completed
    
    var id: String { self.rawValue }
    
    var name: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .completed: return "Completed"
        }
    }
}
