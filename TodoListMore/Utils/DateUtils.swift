//
//  DateUtils.swift
//  TodoListMore
//
//  Created by Harjot Singh on 24/03/25.
//

import Foundation

struct DateUtils {
    /// Check if date is within 3 days from now
    static func isDueSoon(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: date)
        return components.day != nil && components.day! <= 3
    }
    
    /// Check if task is overdue
    static func isOverdue(_ date: Date) -> Bool {
        return date < Date()
    }
    
    /// Format due date for countdown
    static func formatDueDate(_ date: Date) -> String {
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
    
    /// Format time ago from a date
    static func timeAgo(from date: Date) -> String {
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
    
    /// Get start of today and tomorrow for date comparisons
    static func getTodayDateRange() -> (startOfDay: Date, startOfTomorrow: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return (startOfDay, startOfTomorrow)
    }
}