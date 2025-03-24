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
    
    init(mode: FormMode) {
        self.mode = mode
        
        // When in edit mode, we'll load the task in onAppear
    }
    
    var body: some View {
        Form {
            Section(header: Text("Task Details")) {
                TextField("Title", text: $title)
                
                TextField("Description", text: $taskDescription, axis: .vertical)
                    .lineLimit(4...6)
            }
            
            Section(header: Text("Due Date")) {
                Toggle("Set Due Date", isOn: $hasDueDate)
                
                if hasDueDate {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                }
            }
            
            Section(header: Text("Priority")) {
                Picker("Priority", selection: $priority) {
                    Text("Low").tag(Int16(1))
                    Text("Medium").tag(Int16(2))
                    Text("High").tag(Int16(3))
                }
                .pickerStyle(.segmented)
            }
            
            Section(header: Text("Category")) {
                if categories.isEmpty {
                    Text("No categories available")
                        .foregroundColor(.secondary)
                    
                    Button("Add Category") {
                        // This would open a category form in a complete app
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.self) { category in
                                let categoryId = category.value(forKey: "id") as? UUID
                                let name = category.value(forKey: "name") as? String ?? ""
                                let colorHex = category.value(forKey: "colorHex") as? String ?? "#CCCCCC"
                                
                                VStack {
                                    Circle()
                                        .fill(Color(hex: colorHex))
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: selectedCategoryId == categoryId ? 2 : 0)
                                                .padding(2)
                                        )
                                    
                                    Text(name)
                                        .font(.caption)
                                }
                                .onTapGesture {
                                    selectedCategoryId = categoryId
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(height: 60)
                }
            }
        }
        .navigationTitle(isAddMode ? "New Task" : "Edit Task")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveTask()
                    dismiss()
                }
                .disabled(title.isEmpty)
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
    
    private func saveTask() {
        switch mode {
        case .add:
            _ = dataController.addTask(
                title: title,
                description: taskDescription,
                dueDate: hasDueDate ? dueDate : nil,
                priority: priority,
                categoryId: selectedCategoryId
            )
            
        case .edit(let taskId):
            if let uuid = UUID(uuidString: taskId) {
                _ = dataController.updateTask(
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