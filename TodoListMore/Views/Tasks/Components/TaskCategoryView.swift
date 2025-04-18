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
        // Category badge with fixed width and improved visibility
        HStack(spacing: 4) {
            // Color dot - larger for better visibility
            Circle()
                .fill(Color(hex: categoryColorHex))
                .frame(width: 10, height: 10)
                .shadow(color: Color(hex: categoryColorHex).opacity(0.3), radius: 1, x: 0, y: 0)
            
            // Category name with optimized handling for "Uncategorized"
            Text(categoryName == "Uncategorized" ? "No Category" : categoryName)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.9)
        }
        .id(refreshID) // Use ID for forced refresh
        .frame(width: AppTheme.UI.categoryBadgeWidth) // Fixed width for all category badges
        .foregroundColor(Color(hex: categoryColorHex).opacity(0.9)) // Increased opacity for better visibility
        .padding(.vertical, 6) // Increased vertical padding for larger badge
        .padding(.horizontal, 10) // Increased horizontal padding for larger badge
        .background(
            RoundedRectangle(cornerRadius: 10) // Larger corner radius for bigger badge
                .fill(Color(hex: categoryColorHex).opacity(0.18)) // More opaque background for better visibility
                .shadow(color: Color(hex: categoryColorHex).opacity(0.25), radius: 2, x: 0, y: 1) // Enhanced shadow
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