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
    @State private var icon = ""
    @State private var note = ""
    /// Index for preset colors grid selection
    @State private var selectedColorIndex: Int = 0
    @State private var selectedColor: Color = AppTheme.defaultCategoryColor
    @State private var isLoading = false
    
    // Validation states
    @State private var nameError: String? = nil
    @State private var iconError: String? = nil
    @State private var colorError: String? = nil
    
    // Form mode (add new or edit existing category)
    let mode: CategoryFormMode
    let viewModel: CategoryViewModel
    /// Preset colors for quick selection
    let predefinedColors = [
        "#3478F6", // Blue
        "#30D158", // Green
        "#FF9F0A", // Orange
        "#FF453A"  // Red
    ]
    
    var body: some View {
        Form {
            Section(header: Text("Category Details")) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Name", text: $name)
                        .onChange(of: name) { _ in
                            validateName()
                        }
                    
                    if let error = nameError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Icon (emoji)", text: $icon)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: icon) { _ in
                            validateIcon()
                        }
                    
                    if let error = iconError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            Section(header: Text("Color")) {
                ColorPicker("Pick a color", selection: $selectedColor)
                    .labelsHidden()
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Hex code:")
                        TextField("#RRGGBB", text: Binding(
                            get: { selectedColor.hex },
                            set: { newHex in
                                selectedColor = Color(hex: newHex)
                                validateColor(newHex)
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                    }
                    
                    if let error = colorError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Preset colors for quick selection
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                    ForEach(0..<predefinedColors.count, id: \.self) { index in
                        Button(action: {
                            selectedColorIndex = index
                            selectedColor = Color(hex: predefinedColors[index])
                            colorError = nil // Clear any color error when selecting preset
                        }) {
                            Circle()
                                .fill(Color(hex: predefinedColors[index]))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColorIndex == index ? 2 : 0)
                                        .padding(2)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier("CategoryColor_\(index)")
                    }
                }
                .padding(.vertical, 8)
            }

            Section(header: Text("Note")) {
                TextEditor(text: $note)
                    .frame(minHeight: 80)
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
                    // Validate all fields before saving
                    validateAllFields()
                    
                    // Only proceed if all validations pass
                    if hasValidationErrors { return }
                    
                    let success = saveCategory()
                    
                    // Force UI to update immediately after save
                    DispatchQueue.main.async {
                        // Post notification that data has changed to all views that need updating
                        NotificationCenter.default.post(name: .dataDidChange, object: nil)
                    }
                    
                    dismiss()
                }
                .disabled(saveButtonDisabled)
            }
        }
        .disabled(isLoading)
        .onAppear {
            if case .edit(let categoryId) = mode {
                loadCategory(withId: categoryId)
            }
        }
    }
    
    // MARK: - Validation Methods
    
    /// Validates the category name field
    private func validateName() {
        if name.isEmpty {
            nameError = "Name is required"
        } else if name.count > 30 {
            nameError = "Name must be 30 characters or less"
        } else {
            nameError = nil
        }
    }
    
    /// Validates the icon field (should be a single emoji or empty)
    private func validateIcon() {
        if icon.count > 2 {
            iconError = "Please use a single emoji or leave empty"
        } else {
            iconError = nil
        }
    }
    
    /// Validates the color hex code format
    private func validateColor(_ hexCode: String) {
        if !hexCode.isEmpty && !Color.isValidHex(hexCode) {
            colorError = "Invalid hex code format (use #RGB or #RRGGBB)"
        } else {
            colorError = nil
        }
    }
    
    /// Validates all fields at once
    private func validateAllFields() {
        validateName()
        validateIcon()
        validateColor(selectedColor.hex)
    }
    
    /// Returns true if any validation errors exist
    private var hasValidationErrors: Bool {
        return nameError != nil || iconError != nil || colorError != nil
    }
    
    /// Determines if the save button should be disabled
    private var saveButtonDisabled: Bool {
        return name.isEmpty || isLoading || hasValidationErrors
    }
    
    // MARK: - Private Methods
    
    private func loadCategory(withId id: UUID) {
        isLoading = true
        
        let fetchRequest = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let category = try viewContext.fetch(fetchRequest).first {
                name = category.name ?? ""
                // Load icon and note
                icon = category.safeIcon
                note = category.safeNote
                // Load saved color
                if let colorHex = category.colorHex {
                    selectedColor = Color(hex: colorHex)
                    // Update preset grid selection if matching
                    if let idx = predefinedColors.firstIndex(of: colorHex) {
                        selectedColorIndex = idx
                    }
                }
                
                // Validate loaded data
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.validateAllFields()
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
                colorHex: selectedColor.hex,
                icon: icon,
                note: note
            )
        case .edit(let categoryId):
            success = viewModel.updateCategory(
                id: categoryId,
                name: name,
                colorHex: selectedColor.hex,
                icon: icon,
                note: note
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

// Extension to add regex pattern matching to String
extension String {
    func matches(pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}