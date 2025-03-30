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
        VStack(spacing: isEditMode ? 8 : 0) {
            // iOS-native edit mode header - only show when in edit mode, no dividers
            if isEditMode {
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
                    Text("No categories yet. Tap + to add a new category.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
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
                                    .foregroundColor(Color(hex: "#5D4EFF"))
                                    .transition(.scale.combined(with: .opacity))
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
                            top: 6,
                            leading: 16,
                            bottom: 6,
                            trailing: 16
                        ))
                        .listRowBackground(
                            isEditMode && selectedCategoryIds.contains(categoryModel.id) ?
                                Color(hex: "#5D4EFF").opacity(0.15) :
                                Color(UIColor.secondarySystemGroupedBackground)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditMode {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1)) {
                                    if selectedCategoryIds.contains(categoryModel.id) {
                                        selectedCategoryIds.remove(categoryModel.id)
                                    } else {
                                        selectedCategoryIds.insert(categoryModel.id)
                                    }
                                }
                                // Add haptic feedback for selection
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
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
            // Use default list style to maintain rounded corners
            .animation(.easeInOut(duration: 0.2), value: viewModel.categoryModels)
        }
        // Set background color for the entire view
        .background(Color(UIColor.systemGroupedBackground))
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
                    if isEditMode {
                        Text("Done")
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "#5D4EFF"))
                    } else {
                        Image(systemName: "pencil")
                            .foregroundColor(Color(hex: "#5D4EFF"))
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