//
//  CategoryForm.swift
//  TodoListMore
//
//  Created by Harjot Singh on 28/03/25.
//

import SwiftUI
import CoreData

// Form for adding or editing a category
struct CategoryForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
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
    let viewModel: CategoryViewModel
    
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
                    
                    // Force UI to update immediately after save
                    DispatchQueue.main.async {
                        // Post notification that data has changed to all views that need updating
                        NotificationCenter.default.post(name: .dataDidChange, object: nil)
                    }
                    
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
        
        let fetchRequest = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let category = try viewContext.fetch(fetchRequest).first {
                name = category.name ?? ""
                
                if let colorHex = category.colorHex,
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
        
        switch mode {
        case .add:
            success = viewModel.addCategory(
                name: name,
                colorHex: predefinedColors[selectedColorIndex]
            )
            
        case .edit(let categoryId):
            success = viewModel.updateCategory(
                id: categoryId,
                name: name,
                colorHex: predefinedColors[selectedColorIndex]
            )
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