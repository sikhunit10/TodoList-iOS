//
//  ContentView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import UIKit
import AmplitudeSwift

struct ContentView: View {
    // Allow external control of tab selection for deep linking
    @Binding var tabSelection: Int
    @Binding var showNewTaskSheet: Bool
    @State private var highlightedTaskId: UUID?
    
    // For logging purposes
    private let tag = "ContentView"
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dataController: DataController
    
    // Default initializer for previews and when bindings aren't needed
    init() {
        self._tabSelection = .constant(0)
        self._showNewTaskSheet = .constant(false)
    }
    
    // Initializer that accepts bindings for deep linking
    init(tabSelection: Binding<Int>, showNewTaskSheet: Binding<Bool>) {
        self._tabSelection = tabSelection
        self._showNewTaskSheet = showNewTaskSheet
    }
    
    // Define app accent colors
    private let accentLight = Color(hex: "#5D4EFF")
    private let accentDark = Color(hex: "#6F61FF")
    
    var body: some View {
        TabView(selection: $tabSelection) {
            // Tasks tab - white navigation bar with inline title
            NavigationStack {
                TaskListView(highlightedTaskId: $highlightedTaskId)
                    .navigationTitle("Tasks")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(Color.white, for: .navigationBar) // Force white background
                    .sheet(isPresented: $showNewTaskSheet) {
                        TaskFormView(mode: .add) {
                            showNewTaskSheet = false
                        }
                    }
            }
            .background(Color.white) // Force white for any transparent areas
            .tabItem {
                Label("Tasks", systemImage: "checklist.checked")
            }
            .tag(0)
            
            // Categories tab - gray navigation bar with large title
            NavigationStack {
                CategoryListView()
                    .navigationTitle("Categories")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            }
            .tabItem {
                Label("Categories", systemImage: "folder.fill")
            }
            .tag(1)
            
            // Brain Dump tab - white navigation bar with inline title
            NavigationStack {
                BrainDumpView()
                    .navigationTitle("Brain Dump")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(Color.white, for: .navigationBar)
            }
            .tabItem {
                Label("Brain Dump", systemImage: "brain.head.profile")
            }
            .tag(2)
            
            // Settings tab - gray navigation bar with large title
            NavigationStack {
                SettingsView(tabSelection: $tabSelection)
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(3)
        }
        .tint(colorScheme == .dark ? accentDark : accentLight)
        .onReceive(NotificationCenter.default.publisher(for: .didTapTaskNotification)) { notification in
            if let taskId = notification.userInfo?["taskId"] as? UUID {
                print("\(tag): Received notification for task: \(taskId)")
                
                // Set the highlighted task ID immediately
                print("\(tag): Setting highlighted task: \(taskId)")
                highlightedTaskId = taskId
                
                // Then switch to the tasks tab
                tabSelection = 0
                
                // Reset the highlight after 5 seconds to match the TaskListView timeout
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    print("\(tag): Clearing highlighted task")
                    withAnimation {
                        highlightedTaskId = nil
                    }
                }
            }
        }
        .onAppear {
            // Track screen view
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.amplitude.track(eventType: "view_main_screen")
            
            // Enhanced iOS system appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            
            // Apply blur effect for modern look
            if #available(iOS 15.0, *) {
                appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
            }
            
            // Enhance tab bar appearance
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray
            
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
                
                // Create a more compact navigation bar appearance
                // Create two distinct navigation bar appearances
                
                // 1. Task list appearance - white background, consistent height
                let taskNavigationAppearance = UINavigationBarAppearance()
                taskNavigationAppearance.configureWithOpaqueBackground()
                taskNavigationAppearance.backgroundColor = UIColor.systemBackground // White background
                taskNavigationAppearance.shadowColor = .clear
                taskNavigationAppearance.shadowImage = UIImage() // Remove bottom line
                
                // 2. Categories and Settings appearance - gray background with large titles
                let groupedNavigationAppearance = UINavigationBarAppearance()
                groupedNavigationAppearance.configureWithOpaqueBackground()
                groupedNavigationAppearance.backgroundColor = UIColor.systemGroupedBackground // Gray background
                groupedNavigationAppearance.shadowColor = .clear
                groupedNavigationAppearance.shadowImage = UIImage() // Remove bottom line
                
                // Set font sizes for consistent height
                let regularTitleTextAttributes = [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17, weight: .semibold)
                ]
                
                let largeTitleTextAttributes = [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 34, weight: .bold)
                ]
                
                // Apply font settings to both appearances
                taskNavigationAppearance.titleTextAttributes = regularTitleTextAttributes
                groupedNavigationAppearance.titleTextAttributes = regularTitleTextAttributes
                
                taskNavigationAppearance.largeTitleTextAttributes = largeTitleTextAttributes
                groupedNavigationAppearance.largeTitleTextAttributes = largeTitleTextAttributes
                
                // Set default appearances for fallback
                UINavigationBar.appearance().standardAppearance = taskNavigationAppearance
                UINavigationBar.appearance().compactAppearance = taskNavigationAppearance
                UINavigationBar.appearance().scrollEdgeAppearance = groupedNavigationAppearance
                
                // Additional settings to ensure absolutely no bottom line/border
                UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .default)
                UINavigationBar.appearance().shadowImage = UIImage()
                
                // Force update - critical for removing bottom borders
                let navBars = UINavigationBar.appearance()
                navBars.isTranslucent = true
                navBars.tintColor = UIColor(Color(hex: "#5D4EFF"))
                
                // Direct appearance approach - more reliable
                UINavigationBar.appearance().clipsToBounds = true // This helps prevent the hairline from showing
                
                // Make the search bar more compact
                UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes =
                    [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataController.shared)
        .environment(\.managedObjectContext, DataController.shared.container.viewContext)
}
