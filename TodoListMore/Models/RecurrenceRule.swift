//
//  RecurrenceRule.swift
//  TodoListMore
//
//  Created by Automated Patch on 2025-04-17.
//

import Foundation

/// Recurrence options for tasks
enum RecurrenceRule: Int16, CaseIterable, Identifiable {
    case none = 0
    case daily = 1
    case weekly = 2
    case monthly = 3
    case yearly = 4

    var id: Int16 { rawValue }

    /// User-facing name of the recurrence rule
    var name: String {
        switch self {
        case .none:
            return "None"
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        }
    }
}