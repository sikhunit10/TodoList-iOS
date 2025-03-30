//
//  TaskCategoryView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 28/03/25.
//

import SwiftUI
import CoreData
import Combine

/// A view that displays a task's category and listens for updates
struct TaskCategoryView: View {
    // Task and category data
    let task: Task
    
    // State to force updates
    @State private var categoryName: String = "Uncategorized"
    @State private var categoryColorHex: String = AppTheme.accentColor.hex
    @State private var refreshID = UUID()
    
    // Environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        // Category badge with fixed width
        HStack(spacing: 5) {
            // Color dot
            Circle()
                .fill(Color(hex: categoryColorHex))
                .frame(width: 8, height: 8)
                .shadow(color: Color(hex: categoryColorHex).opacity(0.3), radius: 1, x: 0, y: 0)
            
            // Category name with consistent width handling
            Text(categoryName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .id(refreshID) // Use ID for forced refresh
        .frame(width: AppTheme.UI.categoryBadgeWidth) // Fixed width for all category badges
        .padding(.trailing, 2) // Add a bit more padding on right side
        .foregroundColor(Color(hex: categoryColorHex).opacity(0.8))
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: categoryColorHex).opacity(0.12))
                .shadow(color: Color(hex: categoryColorHex).opacity(0.1), radius: 1, x: 0, y: 1)
        )
        // Update on appear
        .onAppear {
            updateCategoryData()
        }
        // Listen for targeted category updates
        .onReceive(NotificationCenter.default.publisher(for: .categoriesDidChange)) { notification in
            // Only refresh if the changed category is this task's category
            guard let updatedCategoryId = notification.userInfo?["categoryId"] as? UUID,
                  let taskCategory = task.category,
                  let categoryId = taskCategory.id,
                  categoryId == updatedCategoryId else {
                return
            }
            
            DispatchQueue.main.async {
                updateCategoryData()
                refreshID = UUID() // Force refresh
            }
        }
        // Task update that might change category assignment
        .onReceive(NotificationCenter.default.publisher(for: .tasksDidChange)) { notification in
            // Only refresh if this specific task was updated 
            guard let updatedTaskId = notification.userInfo?["taskId"] as? UUID,
                  let taskId = task.id,
                  taskId == updatedTaskId else {
                return
            }
            
            DispatchQueue.main.async {
                updateCategoryData()
                refreshID = UUID() // Force refresh
            }
        }
        // Fallback for general data changes
        .onReceive(NotificationCenter.default.publisher(for: .dataDidChange)) { _ in
            DispatchQueue.main.async {
                updateCategoryData()
                refreshID = UUID() // Force refresh
            }
        }
    }
    
    /// Update the local category data from CoreData
    private func updateCategoryData() {
        // Access the latest category data directly 
        if let category = task.category {
            categoryName = category.name ?? "Uncategorized"
            categoryColorHex = category.colorHex ?? "#5D4EFF"
        } else {
            categoryName = "Uncategorized"
            categoryColorHex = AppTheme.accentColor.hex
        }
    }
}