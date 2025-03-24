//
//  TaskFormView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import CoreData

struct TaskFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dataController: DataController
    
    // Form input fields
    @State private var title = ""
    @State private var taskDescription = ""
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var priority: Int16 = 1
    @State private var selectedCategoryId: UUID? = nil
    @State private var categories: [NSManagedObject] = []
    @State private var isLoading = false
    
    // Form mode (add new or edit existing task)
    let mode: FormMode
    
    // Callback for when a task is saved
    var onSave: (() -> Void)?
    
    init(mode: FormMode, onSave: (() -> Void)? = nil) {
        self.mode = mode
        self.onSave = onSave
        
        // When in edit mode, we'll load the task in onAppear
    }
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(hex: "#1C1C1E") : Color(hex: "#F2F2F7"))
                .ignoresSafeArea()
                
            VStack(spacing: 0) {
                // Custom header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .foregroundColor(.accentColor)
                        }
                        
                        Spacer()
                        
                        Text(isAddMode ? "New Task" : "Edit Task")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button {
                            let success = saveTask()
                            onSave?()
                            dismiss()
                        } label: {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundColor(title.isEmpty ? .gray : .accentColor)
                        }
                        .disabled(title.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                .background(colorScheme == .dark ? Color(hex: "#2C2C2E") : .white)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Task Details Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "pencil.line")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 22)
                                Text("Task Details")
                                    .font(.headline)
                            }
                            .padding(.bottom, 4)
                            
                            VStack(spacing: 12) {
                                TextField("Title", text: $title)
                                    .font(.system(size: 17, weight: .medium))
                                    .padding()
                                    .background(colorScheme == .dark ? Color(hex: "#3A3A3C") : Color(hex: "#F9F9FA"))
                                    .cornerRadius(12)
                                
                                TextField("Description", text: $taskDescription, axis: .vertical)
                                    .lineLimit(4...6)
                                    .padding()
                                    .background(colorScheme == .dark ? Color(hex: "#3A3A3C") : Color(hex: "#F9F9FA"))
                                    .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(colorScheme == .dark ? Color(hex: "#2C2C2E") : .white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.0 : 0.05), radius: 8, x: 0, y: 2)
                        
                        // Due Date Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 22)
                                Text("Due Date")
                                    .font(.headline)
                            }
                            .padding(.bottom, 4)
                            
                            VStack(spacing: 12) {
                                Toggle(isOn: $hasDueDate) {
                                    Text("Set Due Date")
                                        .foregroundColor(.primary)
                                }
                                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                                .padding(.vertical, 4)
                                
                                if hasDueDate {
                                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                                        .datePickerStyle(.compact)
                                        .padding(.top, 4)
                                        .transition(.opacity)
                                }
                            }
                        }
                        .padding()
                        .background(colorScheme == .dark ? Color(hex: "#2C2C2E") : .white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.0 : 0.05), radius: 8, x: 0, y: 2)
                        
                        // Priority Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "flag.fill")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 22)
                                Text("Priority")
                                    .font(.headline)
                            }
                            .padding(.bottom, 4)
                            
                            HStack(spacing: 8) {
                                ForEach([Int16(1), Int16(2), Int16(3)], id: \.self) { value in
                                    Button {
                                        priority = value
                                    } label: {
                                        VStack(spacing: 6) {
                                            Circle()
                                                .fill(priorityColor(for: value))
                                                .frame(width: 22, height: 22)
                                                .overlay(
                                                    Circle()
                                                        .strokeBorder(Color.white, lineWidth: priority == value ? 2 : 0)
                                                        .padding(2)
                                                )
                                                .overlay(
                                                    Circle()
                                                        .strokeBorder(priorityColor(for: value), lineWidth: priority == value ? 2 : 0)
                                                )
                                                .shadow(color: priorityColor(for: value).opacity(0.3), radius: 4, x: 0, y: 2)
                                                
                                            Text(priorityText(for: value))
                                                .font(.system(size: 14))
                                                .foregroundColor(priority == value ? priorityColor(for: value) : .primary)
                                                .fontWeight(priority == value ? .semibold : .regular)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(colorScheme == .dark ? Color(hex: "#3A3A3C") : Color(hex: "#F9F9FA"))
                                                .opacity(priority == value ? 0.7 : 0.5)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding()
                        .background(colorScheme == .dark ? Color(hex: "#2C2C2E") : .white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.0 : 0.05), radius: 8, x: 0, y: 2)
                        
                        // Category Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 22)
                                Text("Category")
                                    .font(.headline)
                            }
                            .padding(.bottom, 4)
                            
                            if categories.isEmpty {
                                VStack(alignment: .center, spacing: 12) {
                                    Text("No categories available")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                    
                                    Button {
                                        // This would open a category form in a complete app
                                    } label: {
                                        Label("Add Category", systemImage: "plus.circle")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 16)
                                            .background(Capsule().fill(Color.accentColor))
                                    }
                                    .padding(.bottom, 8)
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                // Add "None" option and categories
                                VStack(alignment: .leading, spacing: 8) {
                                    Button {
                                        selectedCategoryId = nil
                                    } label: {
                                        HStack {
                                            Circle()
                                                .fill(Color(hex: "#CCCCCC"))
                                                .frame(width: 18, height: 18)
                                            
                                            Text("None")
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                            
                                            if selectedCategoryId == nil {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.accentColor)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedCategoryId == nil ? 
                                                      (colorScheme == .dark ? Color(hex: "#3A3A3C") : Color(hex: "#F0F0F5")) : 
                                                      .clear)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Divider()
                                        .padding(.vertical, 8)
                                    
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(categories, id: \.self) { category in
                                                let categoryId = category.value(forKey: "id") as? UUID
                                                let name = category.value(forKey: "name") as? String ?? ""
                                                let colorHex = category.value(forKey: "colorHex") as? String ?? "#CCCCCC"
                                                
                                                Button {
                                                    selectedCategoryId = categoryId
                                                } label: {
                                                    HStack {
                                                        Circle()
                                                            .fill(Color(hex: colorHex))
                                                            .frame(width: 18, height: 18)
                                                        
                                                        Text(name)
                                                            .foregroundColor(.primary)
                                                        
                                                        Spacer()
                                                        
                                                        if selectedCategoryId == categoryId {
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .foregroundColor(.accentColor)
                                                        }
                                                    }
                                                    .contentShape(Rectangle())
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 10)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .fill(selectedCategoryId == categoryId ? 
                                                                  (colorScheme == .dark ? Color(hex: "#3A3A3C") : Color(hex: "#F0F0F5")) : 
                                                                  .clear)
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 220)
                                }
                            }
                        }
                        .padding()
                        .background(colorScheme == .dark ? Color(hex: "#2C2C2E") : .white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.0 : 0.05), radius: 8, x: 0, y: 2)
                    }
                    .padding()
                }
            }
        }
        .disabled(isLoading)
        .onAppear {
            loadCategories()
            
            if case .edit(let taskId) = mode {
                loadTask(withId: taskId)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCategories() {
        isLoading = true
        let context = dataController.container.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Category")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            categories = try context.fetch(fetchRequest)
        } catch {
            print("Error fetching categories: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    private func loadTask(withId id: String) {
        isLoading = true
        
        // Try to convert the string ID to a UUID
        guard let taskId = UUID(uuidString: id) else {
            isLoading = false
            return
        }
        
        let context = dataController.container.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Task")
        fetchRequest.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)
        
        do {
            let tasks = try context.fetch(fetchRequest)
            if let task = tasks.first {
                // Update all form fields with task values
                title = task.value(forKey: "title") as? String ?? ""
                taskDescription = task.value(forKey: "taskDescription") as? String ?? ""
                
                if let taskDueDate = task.value(forKey: "dueDate") as? Date {
                    dueDate = taskDueDate
                    hasDueDate = true
                }
                
                priority = task.value(forKey: "priority") as? Int16 ?? 1
                
                if let category = task.value(forKey: "category") as? NSManagedObject,
                   let categoryId = category.value(forKey: "id") as? UUID {
                    selectedCategoryId = categoryId
                }
            }
        } catch {
            print("Error loading task: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func saveTask() -> Bool {
        var success = false
        
        switch mode {
        case .add:
            if let _ = dataController.addTask(
                title: title,
                description: taskDescription,
                dueDate: hasDueDate ? dueDate : nil,
                priority: priority,
                categoryId: selectedCategoryId
            ) {
                success = true
            }
            
        case .edit(let taskId):
            if let uuid = UUID(uuidString: taskId) {
                success = dataController.updateTask(
                    id: uuid,
                    title: title,
                    description: taskDescription,
                    dueDate: hasDueDate ? dueDate : nil,
                    removeDueDate: !hasDueDate,
                    priority: priority,
                    categoryId: selectedCategoryId,
                    removeCategoryId: selectedCategoryId == nil
                )
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

// Simple enum to represent form mode without directly using Core Data entities
enum FormMode {
    case add
    case edit(String) // Using a String ID instead of Task entity
}
