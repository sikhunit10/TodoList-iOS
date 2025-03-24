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
    @EnvironmentObject private var dataController: DataController
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TaskListView()
                    .navigationTitle("Tasks")
            }
            .tabItem {
                Label("Tasks", systemImage: "checklist")
            }
            .tag(0)
            
            NavigationStack {
                CategoryListView()
                    .navigationTitle("Categories")
            }
            .tabItem {
                Label("Categories", systemImage: "folder")
            }
            .tag(1)
            
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(2)
        }
        .onAppear {
            // Use iOS system appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = appearance
            
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataController.shared)
}