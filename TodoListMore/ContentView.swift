//
//  ContentView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedTab = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dataController: DataController
    
    // Define app accent colors
    private let accentLight = Color(hex: "#5D4EFF")
    private let accentDark = Color(hex: "#6F61FF")
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tasks tab - white navigation bar with inline title
            NavigationStack {
                TaskListView()
                    .navigationTitle("Tasks")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(Color.white, for: .navigationBar) // Force white background
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
            
            // Settings tab - gray navigation bar with large title
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(2)
        }
        .tint(colorScheme == .dark ? accentDark : accentLight)
        .onAppear {
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