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
    
    var body: some View {
        TabView(selection: $tabSelection) {
            // Tasks tab - modern navigation with gradient accent
            NavigationStack {
                TaskListView(highlightedTaskId: $highlightedTaskId)
                    .navigationTitle("Tasks")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(AppTheme.appBackground, for: .navigationBar)
                    .sheet(isPresented: $showNewTaskSheet) {
                        TaskFormView(mode: .add) {
                            showNewTaskSheet = false
                        }
                    }
            }
            .background(AppTheme.appBackground)
            .tabItem {
                Label("Tasks", systemImage: "checklist")
            }
            .tag(0)
            
            // Categories tab - modern grouped style
            NavigationStack {
                CategoryListView()
                    .navigationTitle("Categories")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            }
            .tabItem {
                Label("Categories", systemImage: "folder")
            }
            .tag(1)

            // Brain Dump tab - modern clean style
            NavigationStack {
                BrainDumpView()
                    .navigationTitle("Brain Dump")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(AppTheme.appBackground, for: .navigationBar)
            }
            .tabItem {
                Label("Brain Dump", systemImage: "lightbulb")
            }
            .tag(2)

            // Settings tab - modern grouped style
            NavigationStack {
                SettingsView(tabSelection: $tabSelection)
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(3)
        }
        .tint(
            LinearGradient(
                colors: [AppTheme.accentColor, AppTheme.accentColorDark],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
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

            // Modern tab bar appearance with blur
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithDefaultBackground()
            tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)

            // Modern tab bar styling
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            UITabBar.appearance().unselectedItemTintColor = UIColor(AppTheme.secondaryText)

            if #available(iOS 15.0, *) {
                // Modern navigation bar appearance
                let navigationAppearance = UINavigationBarAppearance()
                navigationAppearance.configureWithOpaqueBackground()
                navigationAppearance.backgroundColor = UIColor(AppTheme.appBackground)
                navigationAppearance.shadowColor = .clear
                navigationAppearance.shadowImage = UIImage()

                // Modern typography
                let titleTextAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                    .foregroundColor: UIColor(AppTheme.primaryText)
                ]

                let largeTitleTextAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 34, weight: .bold),
                    .foregroundColor: UIColor(AppTheme.primaryText)
                ]

                navigationAppearance.titleTextAttributes = titleTextAttributes
                navigationAppearance.largeTitleTextAttributes = largeTitleTextAttributes

                // Apply to all navigation bars
                UINavigationBar.appearance().standardAppearance = navigationAppearance
                UINavigationBar.appearance().compactAppearance = navigationAppearance
                UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance

                // Modern accent color for navigation
                UINavigationBar.appearance().tintColor = UIColor(AppTheme.accentColor)

                // Modern search bar styling
                UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [
                    .font: UIFont.systemFont(ofSize: 15, weight: .medium),
                    .foregroundColor: UIColor(AppTheme.primaryText)
                ]
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataController.shared)
        .environment(\.managedObjectContext, DataController.shared.container.viewContext)
}
