//
//  TodoListMoreApp.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import CoreData
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Set the notification delegate to self
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions
        NotificationManager.shared.requestAuthorization { granted in
            print("Notification permissions granted: \(granted)")
        }
        
        return true
    }
    
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.badge, .sound, .banner, .list])
    }
    
    // Handle user tapping on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Get the task ID from the notification
        let userInfo = response.notification.request.content.userInfo
        
        if let taskIdString = userInfo["taskId"] as? String, 
           let taskId = UUID(uuidString: taskIdString) {
            // Here you could navigate to the task details
            print("User tapped notification for task: \(taskId)")
            
            // Post a notification to navigate to the task and highlight it
            // Do NOT open task detail sheet
            NotificationCenter.default.post(
                name: .didTapTaskNotification,
                object: nil,
                userInfo: ["taskId": taskId]
            )
        }
        
        completionHandler()
    }
}

// Add notification names for task interactions
extension Notification.Name {
    static let didTapTaskNotification = Notification.Name("didTapTaskNotification")
    static let openTaskDetail = Notification.Name("openTaskDetail")
}

@main
struct TodoListMoreApp: App {
    // Register the app delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Inject our CoreData controller into the SwiftUI environment
    @StateObject private var dataController = DataController.shared
    
    init() {
        // Since we can't effectively change the appearance of SearchBar across different views,
        // we'll leave it at the default values and let SwiftUI handle it naturally
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .environmentObject(dataController)
                .onAppear {
                    // Handle any pending notifications when the app starts
                    UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                        if notifications.count > 0 {
                            print("App launched with \(notifications.count) delivered notifications")
                        }
                    }
                }
        }
    }
}