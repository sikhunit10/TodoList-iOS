//
//  NotificationManager.swift
//  TodoListMore
//
//  Created by Harjot Singh on 31/03/25.
//

import Foundation
import UserNotifications
import CoreData

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {
        // Private initializer to ensure singleton pattern
    }
    
    // Request notification permissions with improved memory management
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        // Avoid capturing self, since the notification center doesn't
        // need a reference to this class for the callback
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            // Always dispatch to main thread for UI updates
            DispatchQueue.main.async {
                completion(granted)
            }
            
            if let error = error {
                print("Error requesting notification authorization: \(error.localizedDescription)")
            }
        }
    }
    
    // Check if we have notification permission
    func checkAuthorizationStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
    
    // Schedule a notification for a task
    func scheduleTaskReminder(taskId: UUID, title: String, body: String, dueDate: Date, reminderType: Any, customTime: TimeInterval? = nil) {
        // Convert reminderType to its rawValue if it's a ReminderType enum, or use directly if it's already an Int16
        let reminderTypeValue: Int16
        if let type = reminderType as? ReminderType {
            reminderTypeValue = type.rawValue
        } else if let value = reminderType as? Int16 {
            reminderTypeValue = value
        } else {
            print("Invalid reminder type provided")
            return
        }
        // Check if notification permission is granted
        checkAuthorizationStatus { granted in
            guard granted else {
                print("Notification permissions not granted")
                return
            }
            
            // Remove any existing notifications for this task
            self.removeTaskReminders(taskId: taskId)
            
            // Skip if reminder type is none
            if reminderTypeValue == 0 {
                return
            }
            
            // Calculate notification time
            var notificationTime = dueDate
            
            if reminderTypeValue == 5, let customTime = customTime { // Custom
                // Custom time offset (minutes before)
                notificationTime = dueDate.addingTimeInterval(customTime)
            } else {
                // Standard time intervals
                switch reminderTypeValue {
                case 1: // At time
                    notificationTime = dueDate
                case 2: // 15 minutes before
                    notificationTime = dueDate.addingTimeInterval(-15 * 60)
                case 3: // 1 hour before
                    notificationTime = dueDate.addingTimeInterval(-60 * 60)
                case 4: // 1 day before
                    notificationTime = dueDate.addingTimeInterval(-24 * 60 * 60)
                default:
                    break
                }
            }
            
            // If notification time is in the past or now, schedule a fallback immediate reminder
            if notificationTime <= Date() {
                print("Reminder time is in the past or now: \(notificationTime). Scheduling fallback notification in 30s.")
                notificationTime = Date().addingTimeInterval(30)
            }
            
            // Format due date for notification
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let formattedDueDate = formatter.string(from: dueDate)
            
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = title
            // Use provided body if available, otherwise show due date
            content.body = body.isEmpty ? "Due: \(formattedDueDate)" : body
            content.sound = .default
            
            // Add task ID as user info to identify the notification
            content.userInfo = ["taskId": taskId.uuidString]
            
            // Create time-based trigger
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: notificationTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            // Create unique identifier for this notification
            let identifier = "task-reminder-\(taskId.uuidString)"
            
            // Create request
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            // Add request to notification center
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error.localizedDescription)")
                } else {
                    print("Successfully scheduled notification for task: \(taskId.uuidString) at \(notificationTime)")
                }
            }
        }
    }
    
    // Remove all notifications for a specific task
    func removeTaskReminders(taskId: UUID) {
        let identifier = "task-reminder-\(taskId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    // Remove all pending notifications
    func removeAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}