//
//  TaskStyleUtils.swift
//  TodoListMore
//
//  Created by Harjot Singh on 24/03/25.
//

import SwiftUI

struct TaskStyleUtils {
    /// Returns a gradient for the priority indicator
    static func priorityGradient(priority: Int16) -> [Color] {
        switch priority {
        case 1:
            return [AppTheme.taskPriorityLow, AppTheme.taskPriorityLow.opacity(0.7)]
        case 2:
            return [AppTheme.taskPriorityMedium, AppTheme.taskPriorityMedium.opacity(0.7)]
        case 3:
            return [AppTheme.taskPriorityHigh, AppTheme.taskPriorityHigh.opacity(0.7)]
        default:
            return [AppTheme.taskPriorityLow, AppTheme.taskPriorityLow.opacity(0.7)]
        }
    }
    
    /// Returns the priority color
    static func priorityColor(_ priority: Int16) -> Color {
        switch priority {
        case 1: return AppTheme.taskPriorityLow
        case 2: return AppTheme.taskPriorityMedium
        case 3: return AppTheme.taskPriorityHigh
        default: return AppTheme.taskPriorityLow
        }
    }
}

/// Custom button style with scale animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}