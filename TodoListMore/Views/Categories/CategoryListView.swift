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
    
    @State private var categories: [NSManagedObject] = []
    @State private var isLoading = true
    @State private var showingAddSheet = false
    @State private var editingCategoryId: UUID? = nil
    @State private var searchText = ""
    
    // Edit mode states
    @State private var isEditMode = false
    @State private var selectedCategoryIds = Set<UUID>()
    
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
                                if selectedCategoryIds.count == categories.count && !categories.isEmpty {
                                    selectedCategoryIds.removeAll()
                                } else {
                                    selectedCategoryIds = Set(categories.compactMap { $0.value(forKey: "id") as? UUID })
                                }
                            }
                        }) {
                            Text(selectedCategoryIds.count == categories.count && !categories.isEmpty ? "Deselect All" : "Select All")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "#5D4EFF"))
                        }
                        .disabled(categories.isEmpty)
                        
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
            if isLoading {
                // Show placeholders while loading
                ForEach(0..<3) { index in
                    CategoryPlaceholderRow(index: index)
                        .redacted(reason: .placeholder)
                }
            } else if categories.isEmpty {
                Text("No categories yet. Tap + to add a new category.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(categories, id: \.self) { category in
                    ZStack {
                        CategoryRow(category: category, tasksCount: taskCount(for: category))
                            .swipeActions(edge: .trailing, allowsFullSwipe: !isEditMode) {
                                if !isEditMode {
                                    Button(role: .destructive) {
                                        deleteCategory(category)
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
                        if isEditMode, let categoryId = category.value(forKey: "id") as? UUID {
                            // iOS-style checkmark at trailing edge (right side)
                            HStack {
                                Spacer()
                                
                                ZStack {
                                    // Selection circle
                                    Circle()
                                        .fill(selectedCategoryIds.contains(categoryId) ? 
                                              Color(hex: "#5D4EFF") : 
                                              Color(UIColor.systemFill))
                                        .frame(width: 28, height: 28)
                                    
                                    // Checkmark or empty
                                    if selectedCategoryIds.contains(categoryId) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.trailing, 20)
                                .padding(.leading, 8)
                            }
                            
                            // iOS selection overlay (gray background for selected items)
                            if selectedCategoryIds.contains(categoryId) {
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
                        if isEditMode, let categoryId = category.value(forKey: "id") as? UUID {
                            withAnimation(.spring(dampingFraction: 0.7)) {
                                if selectedCategoryIds.contains(categoryId) {
                                    selectedCategoryIds.remove(categoryId)
                                } else {
                                    selectedCategoryIds.insert(categoryId)
                                }
                            }
                        } else if let categoryId = category.value(forKey: "id") as? UUID {
                            editingCategoryId = categoryId
                        }
                    }
                }
            }
        }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Categories")
        .searchable(text: $searchText, prompt: "Search categories")
        .onChange(of: searchText) { _ in
            loadCategories()
        }
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
                        .foregroundColor(isEditMode ? Color(hex: "#5D4EFF") : Color(hex: "#5D4EFF"))
                }
                .disabled(categories.isEmpty)
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
                CategoryForm(mode: .add)
            }
            .presentationDetents([.medium])
            .onDisappear {
                loadCategories()
            }
        }
        .sheet(item: $editingCategoryId) { categoryId in
            NavigationStack {
                CategoryForm(mode: .edit(categoryId))
            }
            .presentationDetents([.medium])
            .onDisappear {
                loadCategories()
            }
        }
        .overlay {
            if !isLoading && categories.isEmpty {
                ContentUnavailableView(
                    "No Categories",
                    systemImage: "folder.badge.plus",
                    description: Text("Add a category to organize your tasks")
                )
            }
        }
        .onAppear {
            loadCategories()
        }
        .refreshable {
            loadCategories()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataDidChange)) { _ in
            DispatchQueue.main.async {
                loadCategories()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCategories() {
        isLoading = true
        
        let context = dataController.container.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Category")
        
        // Apply search filter if needed
        if !searchText.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", searchText)
        }
        
        // Sort categories by name
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            categories = try context.fetch(fetchRequest)
            isLoading = false
        } catch {
            print("Error fetching categories: \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    private func deleteCategory(_ category: NSManagedObject) {
        withAnimation {
            dataController.delete(category)
            loadCategories()
        }
    }
    
    private func taskCount(for category: NSManagedObject) -> Int {
        guard let tasks = category.value(forKey: "tasks") as? NSSet else {
            return 0
        }
        return tasks.count
    }
    
    private func deleteSelectedCategories() {
        withAnimation(.spring(dampingFraction: 0.7)) {
            // Find all categories with matching IDs and delete them
            for categoryId in selectedCategoryIds {
                if let categoryToDelete = categories.first(where: { 
                    ($0.value(forKey: "id") as? UUID) == categoryId 
                }) {
                    deleteCategory(categoryToDelete)
                }
            }
            
            // Clear selection after deletion
            selectedCategoryIds.removeAll()
            
            // Exit edit mode if there are no more categories
            if categories.isEmpty {
                isEditMode = false
            }
        }
    }
}

// Category row view for displaying a single category
struct CategoryRow: View {
    let category: NSManagedObject
    let tasksCount: Int
    
    var body: some View {
        HStack {
            let colorHex = category.value(forKey: "colorHex") as? String ?? "#CCCCCC"
            let name = category.value(forKey: "name") as? String ?? "Unnamed Category"
            
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 16, height: 16)
            
            Text(name)
                .fontWeight(.medium)
            
            Spacer()
            
            Text("\(tasksCount)")
                .foregroundColor(.secondary)
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(10)
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

// Form for adding or editing a category
struct CategoryForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataController: DataController
    
    @State private var name = ""
    @State private var selectedColorIndex = 0
    @State private var isLoading = false
    
    let predefinedColors = [
        "#3478F6", // Blue
        "#30D158", // Green
        "#FF9F0A", // Orange
        "#FF453A"  // Red
    ]
    
    // Form mode (add new or edit existing category)
    let mode: CategoryFormMode
    
    var body: some View {
        Form {
            Section(header: Text("Category Details")) {
                TextField("Name", text: $name)
            }
            
            Section(header: Text("Color")) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                    ForEach(0..<predefinedColors.count, id: \.self) { index in
                        Circle()
                            .fill(Color(hex: predefinedColors[index]))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColorIndex == index ? 2 : 0)
                                    .padding(2)
                            )
                            .onTapGesture {
                                selectedColorIndex = index
                            }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle(isAddMode ? "New Category" : "Edit Category")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let success = saveCategory()
                    
                    // Post notification that data has changed to all views that need updating
                    NotificationCenter.default.post(name: .dataDidChange, object: nil)
                    
                    dismiss()
                }
                .disabled(name.isEmpty || isLoading)
            }
        }
        .disabled(isLoading)
        .onAppear {
            if case .edit(let categoryId) = mode {
                loadCategory(withId: categoryId)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCategory(withId id: UUID) {
        isLoading = true
        
        let context = dataController.container.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Category")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let categories = try context.fetch(fetchRequest)
            if let category = categories.first {
                name = category.value(forKey: "name") as? String ?? ""
                
                if let colorHex = category.value(forKey: "colorHex") as? String,
                   let index = predefinedColors.firstIndex(of: colorHex) {
                    selectedColorIndex = index
                }
            }
        } catch {
            print("Error loading category: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func saveCategory() -> Bool {
        var success = false
        var categoryId: UUID? = nil
        
        switch mode {
        case .add:
            if let newCategory = dataController.addCategory(
                name: name,
                colorHex: predefinedColors[selectedColorIndex]
            ) as? NSManagedObject {
                success = true
                categoryId = newCategory.value(forKey: "id") as? UUID
            }
            
        case .edit(let id):
            success = dataController.updateCategory(
                id: id,
                name: name,
                colorHex: predefinedColors[selectedColorIndex]
            )
            categoryId = id
        }
        
        // Force immediate UI refresh after saving
        if success {
            // Post notification immediately
            NotificationCenter.default.post(name: .dataDidChange, object: nil)
            
            // Also refresh after a small delay to ensure CoreData has processed changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .dataDidChange, object: nil)
            }
            
            // And again after a slightly longer delay for UI animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: .dataDidChange, object: nil)
            }
        }
        
        return success
    }
    
    // Helper computed property to determine if we're in add mode
    private var isAddMode: Bool {
        if case .add = mode {
            return true
        }
        return false
    }
}

// Form mode for adding or editing a category
enum CategoryFormMode {
    case add
    case edit(UUID)
}

// Extension to make UUID identifiable for the sheet
extension UUID: Identifiable {
    public var id: UUID { self }
}