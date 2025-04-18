//
//  CategoryListView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import CoreData

struct CategoryListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataController: DataController
    
    // Use the view model to manage categories
    @StateObject private var viewModel: CategoryViewModel
    @State private var showingAddSheet = false
    @State private var editingCategoryId: UUID? = nil
    
    // Edit mode states
    @State private var isEditMode = false
    @State private var selectedCategoryIds = Set<UUID>()
    
    init() {
        // Create the view model using StateObject for proper lifecycle management
        // We need to use DataController.shared to ensure we're using the same instance across the app
        let sharedController = DataController.shared
        let viewContext = sharedController.container.viewContext
        
        let vm = CategoryViewModel(
            context: viewContext, 
            dataController: sharedController
        )
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        // Create complex expression components separately
        let spacing: CGFloat = isEditMode ? 8 : 0
        
        VStack(spacing: spacing) {
            // iOS-native edit mode header - only show when in edit mode, no dividers
            if isEditMode {
                HStack {
                    // Left action: Select All / Deselect All
                    Button(action: {
                        withAnimation {
                            let modelsCount = viewModel.categoryModels.count
                            let selectedCount = selectedCategoryIds.count
                            let isEmpty = viewModel.categoryModels.isEmpty
                            
                            if selectedCount == modelsCount && !isEmpty {
                                selectedCategoryIds.removeAll()
                            } else {
                                let allIds = viewModel.categoryModels.map { $0.id }
                                selectedCategoryIds = Set(allIds)
                            }
                        }
                    }) {
                        let modelsCount = viewModel.categoryModels.count
                        let selectedCount = selectedCategoryIds.count
                        let isEmpty = viewModel.categoryModels.isEmpty
                        let isAllSelected = selectedCount == modelsCount && !isEmpty
                        
                        Text(isAllSelected ? "Deselect All" : "Select All")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.accentColor)
                    }
                    .disabled(viewModel.categoryModels.isEmpty)
                    
                    Spacer()
                    
                    // Selected count indicator
                    if selectedCategoryIds.count > 0 {
                        let count = selectedCategoryIds.count
                        let suffix = count > 1 ? "s" : ""
                        Text("\(count) item\(suffix) selected")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Delete action
                    Button(action: {
                        deleteSelectedCategories()
                    }) {
                        if selectedCategoryIds.isEmpty {
                            Text("Delete")
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                        } else {
                            Text("Delete")
                                .font(.system(size: 15))
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(selectedCategoryIds.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(UIColor.systemGroupedBackground)) // Match grouped background color
            }
            
            List {
                // Remove the spacer completely for a tighter layout
                
                if viewModel.isLoading {
                    // Show placeholders while loading
                    ForEach(0..<3) { index in
                        CategoryPlaceholderRow(index: index)
                            .redacted(reason: .placeholder)
                    }
                } else if viewModel.categoryModels.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.accentColor)
                            .padding(.bottom, 5)
                        
                        Text("No Categories Found")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Categories help you organize your tasks more efficiently.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Button(action: {
                            showingAddSheet = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create Category")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppTheme.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.top, 5)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.categoryModels) { categoryModel in
                        HStack {
                            DirectCategoryRow(
                                name: categoryModel.name,
                                colorHex: categoryModel.colorHex,
                                tasksCount: categoryModel.taskCount
                            )
                            
                            // Only show checkmark in edit mode when selected
                            if isEditMode && selectedCategoryIds.contains(categoryModel.id) {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.accentColor)
                                    .transition(.opacity)
                                    .padding(.trailing, 4)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: !isEditMode) {
                            if !isEditMode {
                                Button(role: .destructive) {
                                    deleteCategory(categoryModel.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(
                            top: 8,
                            leading: 16, 
                            bottom: 8,
                            trailing: 16
                        ))
                        .listRowBackground(
                            {
                                let isSelected = isEditMode && selectedCategoryIds.contains(categoryModel.id)
                                if isSelected {
                                    return AppTheme.accentColor.opacity(0.12)
                                } else {
                                    return Color(UIColor.secondarySystemGroupedBackground)
                                }
                            }()
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditMode {
                                let springAnimation = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1)
                                let categoryId = categoryModel.id
                                
                                withAnimation(springAnimation) {
                                    if selectedCategoryIds.contains(categoryId) {
                                        selectedCategoryIds.remove(categoryId)
                                    } else {
                                        selectedCategoryIds.insert(categoryId)
                                    }
                                }
                                // Add haptic feedback for selection
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            } else {
                                // Simply set the editing category ID
                                editingCategoryId = categoryModel.id
                            }
                        }
                        .id(categoryModel.id) // Use stable ID for animations
                        // Use simpler transition to avoid complex expressions
                        .transition(.opacity)
                    }
                    .onMove { indices, newOffset in
                        // This enables iOS to handle the animation automatically
                    }
                }
            }
            .listStyle(.insetGrouped)
            // Use default list style to maintain rounded corners
            .animation(.easeInOut(duration: 0.2), value: viewModel.categoryModels)
        }
        // Set background color for the entire view
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Categories")
        .toolbarBackground(.white, for: .navigationBar)
        .searchable(text: $viewModel.searchText, prompt: "Search categories")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Store current search value
                    let currentSearch = viewModel.searchText
                    
                    // Toggle edit mode and clear selections when exiting
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditMode.toggle()
                        if !isEditMode {
                            selectedCategoryIds.removeAll()
                        }
                    }
                    
                    // Ensure search text is preserved
                    if !currentSearch.isEmpty {
                        viewModel.searchText = currentSearch
                    }
                }) {
                    if isEditMode {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.accentColor)
                    } else {
                        Image(systemName: "pencil")
                            .foregroundColor(AppTheme.accentColor)
                    }
                }
                .disabled(viewModel.categoryModels.isEmpty)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(isEditMode)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                CategoryForm(mode: .add, viewModel: viewModel)
            }
            .presentationDetents([.medium])
            .onDisappear {
                // Force refresh when sheet is dismissed
                DispatchQueue.main.async {
                    viewModel.refreshData()
                }
            }
        }
        .sheet(item: $editingCategoryId) { categoryId in
            NavigationStack {
                CategoryForm(mode: .edit(categoryId), viewModel: viewModel)
            }
            .presentationDetents([.medium])
            .onDisappear {
                // Force refresh when sheet is dismissed
                DispatchQueue.main.async {
                    viewModel.refreshData()
                }
            }
        }
        // Remove overlay since we have an improved in-list empty state
        .onAppear {
            // Force refresh when view appears - this will trigger the refresh timer
            let mainQueue = DispatchQueue.main
            mainQueue.async {
                viewModel.forceRefresh()
            }
        }
        // No need for manual observers anymore as the ViewModel handles that internally
        .refreshable {
            viewModel.refreshData()
        }
    }
    
    // MARK: - Private Methods
    
    
    private func deleteCategory(_ categoryId: UUID) {
        // Use standard animation instead of .smooth which might not be available in this iOS version
        withAnimation {
            viewModel.deleteCategory(id: categoryId)
        }
    }
    
    private func deleteSelectedCategories() {
        // Use standard animation instead of .smooth
        withAnimation {
            // Delete all selected categories by ID
            for categoryId in selectedCategoryIds {
                viewModel.deleteCategory(id: categoryId)
            }
            
            // Clear selection after deletion
            selectedCategoryIds.removeAll()
            
            // Exit edit mode if there are no more categories
            if viewModel.categoryModels.isEmpty {
                isEditMode = false
            }
        }
    }
}

// Direct category row using UI model instead of Core Data entity
struct DirectCategoryRow: View {
    let name: String
    let colorHex: String
    let tasksCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Category color indicator with subtle shadow
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex).opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 16, height: 16)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Category name with better typography
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .contentTransition(.identity)
                
                // Subtle indicator of task count
                Text(tasksCount == 1 ? "1 task" : "\(tasksCount) tasks")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Task count badge with category color
            Text("\(tasksCount)")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: colorHex))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: colorHex).opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: colorHex).opacity(0.2), lineWidth: 1)
                )
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// Placeholder row for loading state
struct CategoryPlaceholderRow: View {
    let index: Int
    
    private let sampleNames = ["Work", "Personal", "Shopping"]
    private let sampleColors = ["#3478F6", "#30D158", "#FF9F0A"]
    private let sampleCounts = [5, 3, 2]
    
    var body: some View {
        HStack(spacing: 12) {
            // Category color indicator placeholder
            ZStack {
                Circle()
                    .fill(Color(hex: sampleColors[index % sampleColors.count]).opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Circle()
                    .fill(Color(hex: sampleColors[index % sampleColors.count]))
                    .frame(width: 16, height: 16)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Category name placeholder
                Text(sampleNames[index % sampleNames.count])
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                // Task count text placeholder
                let count = sampleCounts[index % sampleCounts.count]
                Text(count == 1 ? "1 task" : "\(count) tasks")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Count badge placeholder
            let colorHex = sampleColors[index % sampleColors.count]
            let count = sampleCounts[index % sampleCounts.count]
            Text("\(count)")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: colorHex))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: colorHex).opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: colorHex).opacity(0.2), lineWidth: 1)
                )
        }
        .padding(.vertical, 6)
    }
}

// Extension to make UUID identifiable for the sheet
extension UUID: Identifiable {
    public var id: UUID { self }
}

// Namespace wrapper for matchedGeometryEffect - Allows using it in static contexts
struct NamespaceWrapper {
    static let namespace = Namespace().wrappedValue
}