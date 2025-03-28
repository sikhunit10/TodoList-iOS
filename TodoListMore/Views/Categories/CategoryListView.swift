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
        let vm = CategoryViewModel(
            context: DataController.shared.container.viewContext, 
            dataController: DataController.shared
        )
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // iOS-native edit mode header - only show when in edit mode
            if isEditMode {
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack {
                        // Left action: Select All / Deselect All
                        Button(action: {
                            withAnimation {
                                if selectedCategoryIds.count == viewModel.categoryModels.count && !viewModel.categoryModels.isEmpty {
                                    selectedCategoryIds.removeAll()
                                } else {
                                    selectedCategoryIds = Set(viewModel.categoryModels.map { $0.id })
                                }
                            }
                        }) {
                            let isAllSelected = selectedCategoryIds.count == viewModel.categoryModels.count && !viewModel.categoryModels.isEmpty
                            Text(isAllSelected ? "Deselect All" : "Select All")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "#5D4EFF"))
                        }
                        .disabled(viewModel.categoryModels.isEmpty)
                        
                        Spacer()
                        
                        // Selected count indicator
                        if selectedCategoryIds.count > 0 {
                            Text("\(selectedCategoryIds.count) item\(selectedCategoryIds.count > 1 ? "s" : "") selected")
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
                    .padding(.vertical, 12)
                    
                    Divider()
                }
                .background(Color(UIColor.systemBackground))
            }
            
            List {
                if viewModel.isLoading {
                    // Show placeholders while loading
                    ForEach(0..<3) { index in
                        CategoryPlaceholderRow(index: index)
                            .redacted(reason: .placeholder)
                    }
                } else if viewModel.categoryModels.isEmpty {
                    Text("No categories yet. Tap + to add a new category.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.categoryModels) { categoryModel in
                        ZStack {
                            DirectCategoryRow(
                                name: categoryModel.name,
                                colorHex: categoryModel.colorHex,
                                tasksCount: categoryModel.taskCount
                            )
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
                                top: 6,
                                leading: 16,
                                bottom: 6,
                                trailing: isEditMode ? 60 : 16
                            ))
                            
                            // Modified appearance in edit mode - iOS-style selection
                            if isEditMode {
                                // iOS-style checkmark at trailing edge
                                HStack {
                                    Spacer()
                                    
                                    ZStack {
                                        // Selection circle
                                        Circle()
                                            .fill(selectedCategoryIds.contains(categoryModel.id) ? 
                                                  Color(hex: "#5D4EFF") : 
                                                  Color(UIColor.systemFill))
                                            .frame(width: 28, height: 28)
                                        
                                        // Checkmark or empty
                                        if selectedCategoryIds.contains(categoryModel.id) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.trailing, 20)
                                    .padding(.leading, 8)
                                }
                                
                                // iOS selection overlay
                                if selectedCategoryIds.contains(categoryModel.id) {
                                    Color(UIColor.systemGray5)
                                        .opacity(0.35)
                                        .cornerRadius(10)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditMode {
                                withAnimation(.spring(dampingFraction: 0.7)) {
                                    if selectedCategoryIds.contains(categoryModel.id) {
                                        selectedCategoryIds.remove(categoryModel.id)
                                    } else {
                                        selectedCategoryIds.insert(categoryModel.id)
                                    }
                                }
                            } else {
                                editingCategoryId = categoryModel.id
                            }
                        }
                        .id(categoryModel.id) // Use stable ID for animations
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                    .onMove { indices, newOffset in
                        // This enables iOS to handle the animation automatically
                    }
                }
            }
            .listStyle(.insetGrouped)
            // Use animation modifier directly at the list level for categories
            .animation(.easeInOut(duration: 0.2), value: viewModel.categoryModels)
        }
        .navigationTitle("Categories")
        .searchable(text: $viewModel.searchText, prompt: "Search categories")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation {
                        // Toggle edit mode and clear selections when exiting
                        isEditMode.toggle()
                        if !isEditMode {
                            selectedCategoryIds.removeAll()
                        }
                    }
                }) {
                    Text(isEditMode ? "Done" : "Edit")
                        .fontWeight(isEditMode ? .semibold : .regular)
                        .foregroundColor(Color(hex: "#5D4EFF"))
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
        .overlay {
            if !viewModel.isLoading && viewModel.categoryModels.isEmpty {
                ContentUnavailableView(
                    "No Categories",
                    systemImage: "folder.badge.plus",
                    description: Text("Add a category to organize your tasks")
                )
            }
        }
        .onAppear {
            // Force refresh when view appears - this will trigger the refresh timer
            DispatchQueue.main.async {
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
        withAnimation(.smooth) {
            viewModel.deleteCategory(id: categoryId)
        }
    }
    
    private func deleteSelectedCategories() {
        withAnimation(.smooth) {
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
        HStack {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 16, height: 16)
            
            Text(name)
                .fontWeight(.medium)
                // Prevent flicker during transitions
                .contentTransition(.identity)
            
            Spacer()
            
            Text("\(tasksCount)")
                .foregroundColor(.secondary)
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                // Fix the size to prevent jumping during animations
                .fixedSize()
        }
        .padding(.vertical, 4)
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
        HStack {
            Circle()
                .fill(Color(hex: sampleColors[index % sampleColors.count]))
                .frame(width: 16, height: 16)
            
            Text(sampleNames[index % sampleNames.count])
                .fontWeight(.medium)
            
            Spacer()
            
            Text("\(sampleCounts[index % sampleCounts.count])")
                .foregroundColor(.secondary)
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
        .padding(.vertical, 4)
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