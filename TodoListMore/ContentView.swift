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
            NavigationStack {
                TaskListView()
                    .navigationTitle("Tasks")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Tasks", systemImage: "checklist.checked")
            }
            .tag(0)
            
            NavigationStack {
                CategoryListView()
                    .navigationTitle("Categories")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Categories", systemImage: "folder.fill")
            }
            .tag(1)
            
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.large)
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
                
                // Enhance navigation bar appearance
                let navigationAppearance = UINavigationBarAppearance()
                navigationAppearance.configureWithOpaqueBackground()
                navigationAppearance.backgroundColor = UIColor.systemBackground
                navigationAppearance.shadowColor = .clear
                
                UINavigationBar.appearance().standardAppearance = navigationAppearance
                UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataController.shared)
        .environment(\.managedObjectContext, DataController.shared.container.viewContext)
}