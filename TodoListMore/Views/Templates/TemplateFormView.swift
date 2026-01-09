//
//  TemplateFormView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import CoreData
import AmplitudeSwift

struct TemplateFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataController: DataController
    
    @State private var name = ""
    @State private var description = ""
    @State private var category = "General"
    @State private var icon = "list.bullet"
    @State private var tasks: [EditableTemplateTask] = []
    @State private var showingDeleteConfirmation = false
    
    let mode: TemplateFormMode
    let onSave: () -> Void
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    private var templateId: UUID? {
        if case .edit(let template) = mode {
            return template.id
        }
        return nil
    }
    
    private let availableCategories = ["General", "Work", "Personal", "Travel", "Health", "Social", "Career", "Life Events", "Productivity"]
    private let availableIcons = ["list.bullet", "briefcase", "person", "airplane", "stethoscope", "heart", "graduationcap", "house", "calendar", "star", "flag", "target", "lightbulb", "wrench", "book", "camera", "music.note", "gamecontroller", "cart", "bag"]
    
    init(mode: TemplateFormMode, onSave: @escaping () -> Void) {
        self.mode = mode
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Template info section
                Section {
                    TextField("Template Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                    
                    // Category picker
                    Picker("Category", selection: $category) {
                        ForEach(availableCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    
                    // Icon picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(availableIcons, id: \.self) { iconName in
                                Button(action: {
                                    icon = iconName
                                }) {
                                    Image(systemName: iconName)
                                        .font(.system(size: 20))
                                        .foregroundColor(icon == iconName ? .white : Color(hex: "#5D4EFF"))
                                        .frame(width: 40, height: 40)
                                        .background(icon == iconName ? Color(hex: "#5D4EFF") : Color(hex: "#5D4EFF").opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                } header: {
                    Text("Template Details")
                }
                
                // Tasks section
                Section {
                    ForEach(tasks.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("Task title", text: $tasks[index].title)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button(action: {
                                    tasks.remove(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 20))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            TextField("Description (optional)", text: $tasks[index].description)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 14))
                            
                            HStack {
                                // Priority picker
                                Picker("Priority", selection: $tasks[index].priority) {
                                    ForEach(TaskPriority.allCases) { priority in
                                        Label(priority.name, systemImage: priority.icon)
                                            .tag(priority)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity)
                                
                                // Due date offset
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Due in")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        TextField("Days", value: $tasks[index].dueDateOffset, format: .number)
                                            .textFieldStyle(.roundedBorder)
                                            .keyboardType(.numbersAndPunctuation)
                                            .frame(width: 60)
                                        
                                        Text("days")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Button(action: {
                        tasks.append(EditableTemplateTask())
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color(hex: "#5D4EFF"))
                            Text("Add Task")
                                .foregroundColor(Color(hex: "#5D4EFF"))
                        }
                    }
                    .buttonStyle(.plain)
                    
                } header: {
                    Text("Tasks (\(tasks.count))")
                }
                
                // Delete section (for editing)
                if isEditing {
                    Section {
                        Button(role: .destructive, action: {
                            showingDeleteConfirmation = true
                        }) {
                            Label("Delete Template", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Template" : "New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || tasks.isEmpty)
                }
            }
        }
        .onAppear {
            loadTemplateData()
        }
        .alert("Delete Template", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTemplate()
            }
        } message: {
            Text("This will permanently delete this template. This action cannot be undone.")
        }
    }
    
    // MARK: - Actions
    
    private func loadTemplateData() {
        if case .edit(let template) = mode {
            name = template.safeName
            description = template.safeDescription
            category = template.safeCategory
            icon = template.safeIcon
            
            tasks = template.templateTasksArray.map { templateTask in
                EditableTemplateTask(
                    title: templateTask.safeTitle,
                    description: templateTask.safeDescription,
                    priority: templateTask.priorityEnum,
                    dueDateOffset: templateTask.dueDateOffset,
                    categoryName: templateTask.safeCategoryName
                )
            }
        } else {
            // Add a default task for new templates
            tasks = [EditableTemplateTask()]
        }
    }
    
    private func saveTemplate() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty, !tasks.isEmpty else { return }
        
        let taskData = tasks.map { task in
            TemplateTaskData(
                title: task.title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: task.description.trimmingCharacters(in: .whitespacesAndNewlines),
                priority: task.priority,
                dueDateOffset: task.dueDateOffset,
                categoryName: task.categoryName
            )
        }
        
        let success: Bool
        
        if let templateId = templateId {
            // Update existing template
            success = dataController.updateTemplate(
                id: templateId,
                name: trimmedName,
                description: trimmedDescription,
                category: category,
                icon: icon,
                tasks: taskData
            )
            
            if success {
                // Track template update
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.amplitude.track(
                    eventType: "template_updated",
                    eventProperties: [
                        "template_name": trimmedName,
                        "task_count": tasks.count,
                        "category": category
                    ]
                )
            }
        } else {
            // Create new template
            let template = dataController.createTemplate(
                name: trimmedName,
                description: trimmedDescription,
                category: category,
                icon: icon,
                tasks: taskData
            )
            success = template != nil
            
            if success {
                // Track template creation
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.amplitude.track(
                    eventType: "template_created",
                    eventProperties: [
                        "template_name": trimmedName,
                        "task_count": tasks.count,
                        "category": category
                    ]
                )
            }
        }
        
        if success {
            onSave()
            dismiss()
        }
    }
    
    private func deleteTemplate() {
        guard let templateId = templateId else { return }
        
        let success = dataController.deleteTemplate(id: templateId)
        
        if success {
            // Track template deletion
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.amplitude.track(
                eventType: "template_deleted",
                eventProperties: ["template_name": name]
            )
            
            dismiss()
        }
    }
}

// MARK: - Supporting Types

enum TemplateFormMode {
    case create
    case edit(TaskTemplate)
}

struct EditableTemplateTask {
    var title: String = ""
    var description: String = ""
    var priority: TaskPriority = .medium
    var dueDateOffset: Int32 = 0
    var categoryName: String = ""
}

#Preview {
    TemplateFormView(mode: .create, onSave: {})
        .environmentObject(DataController.shared)
        .environment(\.managedObjectContext, DataController.shared.container.viewContext)
}