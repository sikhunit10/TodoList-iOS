//
//  TaskReminders.swift
//  TodoListMore
//
//  Created by Harjot Singh on 31/03/25.
//

import Foundation

/// Reminder types for task notifications
enum ReminderType: Int16, CaseIterable, Identifiable {
    case none = 0
    case atTime = 1
    case fifteenMinutesBefore = 2
    case oneHourBefore = 3
    case oneDayBefore = 4
    case custom = 5
    
    var id: Int16 { self.rawValue }
    
    var name: String {
        switch self {
        case .none: return "None"
        case .atTime: return "At time of event"
        case .fifteenMinutesBefore: return "15 minutes before"
        case .oneHourBefore: return "1 hour before"
        case .oneDayBefore: return "1 day before"
        case .custom: return "Custom"
        }
    }
    
    var timeInterval: TimeInterval? {
        switch self {
        case .none: return nil
        case .atTime: return 0
        case .fifteenMinutesBefore: return -15 * 60
        case .oneHourBefore: return -60 * 60
        case .oneDayBefore: return -24 * 60 * 60
        case .custom: return nil // Requires a custom time
        }
    }
}