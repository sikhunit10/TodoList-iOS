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
    
    var body: some View {
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
                    CategoryRow(category: category, tasksCount: taskCount(for: category))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteCategory(category)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .onTapGesture {
                            if let categoryId = category.value(forKey: "id") as? UUID {
                                editingCategoryId = categoryId
                            }
                        }
                }
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search categories")
        .onChange(of: searchText) { _ in
            loadCategories()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
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
                    saveCategory()
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
    
    private func saveCategory() {
        switch mode {
        case .add:
            _ = dataController.addCategory(
                name: name,
                colorHex: predefinedColors[selectedColorIndex]
            )
            
        case .edit(let categoryId):
            _ = dataController.updateCategory(
                id: categoryId,
                name: name,
                colorHex: predefinedColors[selectedColorIndex]
            )
        }
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