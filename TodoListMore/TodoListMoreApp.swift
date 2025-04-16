//
//  TodoListMoreApp.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import CoreData
import UserNotifications
import WidgetKit
import AmplitudeSwift

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let amplitude = Amplitude(configuration: Configuration(
        apiKey: "1e017dc2ffb6ad549c641b7fb9e4cb2e",
        trackingOptions: TrackingOptions()
    ))
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Set the notification delegate to self
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions
        NotificationManager.shared.requestAuthorization { granted in
            print("Notification permissions granted: \(granted)")
        }
        
        // Initialize Amplitude
        let isFirstLaunch = UserDefaults.standard.bool(forKey: "HasLaunchedBefore") == false
        
        if isFirstLaunch {
            // This is a first launch/install
            amplitude.track(eventType: "app_installed")
            
            // Mark that the app has been launched
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            UserDefaults.standard.set(Date(), forKey: "InstallDate")
        }
        
        // Track app_opened event with session data
        let sessionId = UUID().uuidString
        UserDefaults.standard.set(sessionId, forKey: "CurrentSessionId")
        UserDefaults.standard.set(Date(), forKey: "SessionStartTime")
        
        amplitude.track(
            eventType: "app_opened",
            eventProperties: [
                "session_id": sessionId,
                "days_since_install": daysSinceInstall()
            ]
        )
        
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
            
            // Track notification interaction
            amplitude.track(
                eventType: "notification_tapped",
                eventProperties: ["task_id": taskIdString]
            )
            
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
    
    // Helper to calculate days since app install
    func daysSinceInstall() -> Int {
        guard let installDate = UserDefaults.standard.object(forKey: "InstallDate") as? Date else {
            // If no install date, set it now and return 0
            UserDefaults.standard.set(Date(), forKey: "InstallDate")
            return 0
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: installDate, to: Date())
        return components.day ?? 0
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
    
    // For handling widget deep links
    @StateObject private var deepLinkManager = DeepLinkManager()
    @State private var tabSelection = 0
    @State private var showNewTaskSheet = false
    
    init() {
        // Register the URL scheme for deep linking from widgets
        print("Registering URL types for deep linking")
        
        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Track session resume
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            let sessionId = UUID().uuidString
            UserDefaults.standard.set(sessionId, forKey: "CurrentSessionId")
            UserDefaults.standard.set(Date(), forKey: "SessionStartTime")
            
            appDelegate?.amplitude.track(
                eventType: "app_became_active",
                eventProperties: [
                    "session_id": sessionId,
                    "days_since_install": appDelegate?.daysSinceInstall() ?? 0
                ]
            )
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Track session end and calculate duration
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            
            let sessionId = UserDefaults.standard.string(forKey: "CurrentSessionId") ?? "unknown"
            let sessionStartTime = UserDefaults.standard.object(forKey: "SessionStartTime") as? Date ?? Date()
            let sessionDuration = Int(Date().timeIntervalSince(sessionStartTime))
            
            appDelegate?.amplitude.track(
                eventType: "app_resigned_active",
                eventProperties: [
                    "session_id": sessionId,
                    "session_duration_seconds": sessionDuration
                ]
            )
        }
        
        // Register for app termination to track potential uninstalls
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Save last session timestamp for uninstall detection
            UserDefaults.standard.set(Date(), forKey: "LastSessionTime")
            
            // Track app termination
            let sessionId = UserDefaults.standard.string(forKey: "CurrentSessionId") ?? "unknown"
            let sessionStartTime = UserDefaults.standard.object(forKey: "SessionStartTime") as? Date ?? Date()
            let sessionDuration = Int(Date().timeIntervalSince(sessionStartTime))
            
            (UIApplication.shared.delegate as? AppDelegate)?.amplitude.track(
                eventType: "app_terminated",
                eventProperties: [
                    "session_id": sessionId,
                    "session_duration_seconds": sessionDuration
                ]
            )
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                tabSelection: $tabSelection, 
                showNewTaskSheet: $showNewTaskSheet
            )
            .environment(\.managedObjectContext, dataController.container.viewContext)
            .environmentObject(dataController)
            .environmentObject(deepLinkManager)
            .onAppear {
                // Handle any pending notifications when the app starts
                UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                    if notifications.count > 0 {
                        print("App launched with \(notifications.count) delivered notifications")
                    }
                }
            }
            .onOpenURL { url in
                // Handle deep links from widgets
                print("Received deep link: \(url)")
                deepLinkManager.handle(url: url)
                
                // Process the deep link and update UI accordingly
                if let deepLink = DeepLink(url: url) {
                    switch deepLink {
                    case .today:
                        tabSelection = 0 // Tasks tab
                        // Refresh widgets when navigating from widget
                        WidgetCenter.shared.reloadAllTimelines()
                    case .priority:
                        tabSelection = 0 // Tasks tab
                        // Refresh widgets when navigating from widget
                        WidgetCenter.shared.reloadAllTimelines()
                    case .newTask:
                        tabSelection = 0 // Tasks tab
                        showNewTaskSheet = true
                        // Refresh widgets when creating a new task
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            }
        }
    }
}
