//
//  TaskFormView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import CoreData
import UserNotifications
import UIKit

struct TaskFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dataController: DataController
    
    // Form input fields
    @State private var title = ""
    @State private var taskDescription = ""
    @State private var dueDate = Date()
    @State private var priority: Int16 = 1
    @State private var selectedCategoryId: UUID? = nil
    @State private var categories: [NSManagedObject] = []
    @State private var isLoading = false
    @State private var showCategoryForm = false
    // State for tracking date changes
    @State private var previousDate = Date()
    
    // Reminder fields
    @State private var reminderType: Int16 = 0
    @State private var customReminderMinutes: Double = 30
    @State private var showCustomTimePicker = false
    
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
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 4) {
                                        Text("Title")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Circle()
                                            .fill(Color.accentColor)
                                            .frame(width: 4, height: 4)
                                    }
                                    
                                    TextField("Enter task title", text: $title)
                                        .font(.system(size: 17, weight: .medium))
                                        .padding()
                                        .background(colorScheme == .dark ? Color(hex: "#3A3A3C") : Color(hex: "#F9F9FA"))
                                        .cornerRadius(12)
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Description")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    TextField("Enter task description (optional)", text: $taskDescription, axis: .vertical)
                                        .lineLimit(4...6)
                                        .padding()
                                        .background(colorScheme == .dark ? Color(hex: "#3A3A3C") : Color(hex: "#F9F9FA"))
                                        .cornerRadius(12)
                                }
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
                                HStack(spacing: 4) {
                                    Text("Due Date")
                                        .font(.headline)
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .padding(.bottom, 4)
                            
                            VStack(spacing: 12) {
                                // Simple clean layout
                                HStack(alignment: .center, spacing: 12) {
                                    // Date picker with border and improved handling
                                    DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .onChange(of: dueDate) { newDate in
                                            // Store the previous date for comparison
                                            let oldDate = previousDate
                                            previousDate = newDate
                                            
                                            // If changing to a date in the past, warn user
                                            if newDate < Date() && oldDate >= Date() {
                                                print("Warning: Setting due date to a time in the past")
                                            }
                                            
                                            // Update reminder settings if needed
                                            updateReminderSettingsForNewDate()
                                        }
                                        .padding(10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(colorScheme == .dark ? Color(hex: "#3A3A3C") : Color(hex: "#F9F9FA"))
                                        )
                                    
                                    Spacer()
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
                                HStack(spacing: 4) {
                                    Text("Priority")
                                        .font(.headline)
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 4, height: 4)
                                }
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
                                        // Present category form as a sheet
                                        showCategoryForm = true
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
                                                .fill(Color(hex: "#5D4EFF"))
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
                                                let colorHex = category.value(forKey: "colorHex") as? String ?? "#5D4EFF"
                                                
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
                                            
                                            // Add new category button
                                            Button {
                                                showCategoryForm = true
                                            } label: {
                                                HStack {
                                                    Image(systemName: "plus.circle.fill")
                                                        .foregroundColor(.accentColor)
                                                        .frame(width: 18, height: 18)
                                                    
                                                    Text("Add New Category")
                                                        .foregroundColor(.accentColor)
                                                        .fontWeight(.medium)
                                                    
                                                    Spacer()
                                                }
                                                .contentShape(Rectangle())
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 10)
                                            }
                                            .buttonStyle(.plain)
                                            .padding(.top, 4)
                                        }
                                    }
                                    .frame(maxHeight: 260)
                                }
                            }
                        }
                        .padding()
                        .background(colorScheme == .dark ? Color(hex: "#2C2C2E") : .white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.0 : 0.05), radius: 8, x: 0, y: 2)
                        
                        // Reminder Card
                        VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "bell.fill")
                                        .foregroundColor(.accentColor)
                                        .frame(width: 22)
                                    Text("Reminder")
                                        .font(.headline)
                                }
                                .padding(.bottom, 4)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    // Use ReminderType enum for options
                                    ForEach(ReminderType.allCases, id: \.id) { option in
                                        Button {
                                            reminderType = option.rawValue
                                            if option == .custom { // Custom
                                                showCustomTimePicker = true
                                            } else {
                                                showCustomTimePicker = false
                                            }
                                        } label: {
                                            HStack {
                                                Text(option.name)
                                                    .foregroundColor(.primary)
                                                
                                                Spacer()
                                                
                                                if reminderType == option.rawValue {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.accentColor)
                                                }
                                            }
                                            .contentShape(Rectangle())
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(reminderType == option.rawValue ? 
                                                        (colorScheme == .dark ? Color(hex: "#3A3A3C") : Color(hex: "#F0F0F5")) : 
                                                        .clear)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    // Custom time picker
                                    if showCustomTimePicker {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Minutes before due time:")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .padding(.top, 8)
                                            
                                            HStack {
                                                Text("\(Int(customReminderMinutes))")
                                                    .frame(width: 40, alignment: .trailing)
                                                    .font(.headline)
                                                
                                                Slider(value: $customReminderMinutes, in: 5...720, step: 5)
                                                    .accentColor(.accentColor)
                                                    .onChange(of: customReminderMinutes) { newValue in
                                                        // Ensure the reminder time is not in the past
                                                        if reminderType == 5 {
                                                            let reminderTime = dueDate.addingTimeInterval(-(newValue * 60))
                                                            if reminderTime < Date() && dueDate > Date() {
                                                                // Calculate maximum safe value
                                                                let maxMinutes = max(5, (dueDate.timeIntervalSince(Date()) / 60) - 1)
                                                                
                                                                // If current setting exceeds maximum, adjust it
                                                                if newValue > maxMinutes {
                                                                    DispatchQueue.main.async {
                                                                        customReminderMinutes = maxMinutes
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                            }
                                            
                                            Text("Reminder will be sent \(Int(customReminderMinutes) >= 60 ? "\(Int(customReminderMinutes) / 60) hour\(Int(customReminderMinutes) / 60 > 1 ? "s" : "")\(Int(customReminderMinutes) % 60 > 0 ? " \(Int(customReminderMinutes) % 60) minutes" : "")" : "\(Int(customReminderMinutes)) minutes") before the task is due")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(colorScheme == .dark ? Color(hex: "#3A3A3C") : Color(hex: "#F9F9FA"))
                                        .cornerRadius(12)
                                        .padding(.top, 8)
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
        .sheet(isPresented: $showCategoryForm) {
            NavigationStack {
                QuickCategoryForm()
                    .environmentObject(dataController)
            }
            .presentationDetents([.medium])
            .onDisappear {
                loadCategories()
            }
        }
        .onAppear {
            // Initialize previousDate with the current dueDate
            previousDate = dueDate
            
            loadCategories()
            
            if case .edit(let taskId) = mode {
                loadTask(withId: taskId)
            }
        }
    }
    
    private func priorityColor(for value: Int16) -> Color {
        switch value {
        case 1: return AppTheme.taskPriorityLow
        case 2: return AppTheme.taskPriorityMedium
        case 3: return AppTheme.taskPriorityHigh
        default: return .blue
        }
    }
    
    private func priorityText(for value: Int16) -> String {
        switch value {
        case 1: return "Low"
        case 2: return "Medium"
        case 3: return "High"
        default: return ""
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
                    previousDate = taskDueDate
                }
                
                priority = task.value(forKey: "priority") as? Int16 ?? 1
                
                if let category = task.value(forKey: "category") as? NSManagedObject,
                   let categoryId = category.value(forKey: "id") as? UUID {
                    selectedCategoryId = categoryId
                }
                
                // Only try to load reminder settings if they're supported
                if dataController.hasReminderSupport {
                    // Safely try to load the reminder settings
                    do {
                        reminderType = (task.value(forKey: "reminderType") as? Int16) ?? 0
                    } catch {
                        // Property doesn't exist, ignore
                    }
                    
                    do {
                        if let customTime = task.value(forKey: "customReminderTime") as? Double {
                            // Convert from seconds to minutes for display
                            customReminderMinutes = abs(customTime) / 60
                        }
                    } catch {
                        // Property doesn't exist, ignore
                    }
                    
                    // Show custom time picker if reminder type is custom (type 5)
                    showCustomTimePicker = (reminderType == 5)
                }
            }
        } catch {
            print("Error loading task: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func saveTask() -> Bool {
        var success = false
        
        // Calculate custom reminder time in seconds if needed
        var customReminderTime: Double? = nil
        if reminderType == 5 { // Custom reminder type
            // Convert minutes to seconds and make it negative (time before due date)
            customReminderTime = -(customReminderMinutes * 60)
        }
        
        switch mode {
        case .add:
            if let _ = dataController.addTask(
                title: title,
                description: taskDescription,
                dueDate: dueDate,
                priority: priority,
                categoryId: selectedCategoryId,
                reminderType: reminderType,
                customReminderTime: customReminderTime
            ) {
                success = true
            }
            
        case .edit(let taskId):
            if let uuid = UUID(uuidString: taskId) {
                success = dataController.updateTask(
                    id: uuid,
                    title: title,
                    description: taskDescription,
                    dueDate: dueDate,
                    removeDueDate: false,
                    priority: priority,
                    categoryId: selectedCategoryId,
                    removeCategoryId: selectedCategoryId == nil,
                    reminderType: reminderType,
                    customReminderTime: customReminderTime
                )
            }
        }
        
        return success
    }
    
    // Helper method to update reminder settings when date changes
    private func updateReminderSettingsForNewDate() {
        // If the due date is in the past and reminders are set, warn the user
        if dueDate < Date() && reminderType != 0 {
            // Reminder for past date doesn't make sense - provide feedback
            print("Warning: Setting reminder for a date in the past")
            
            // Optionally could reset the reminder type to None here
            // reminderType = 0
        }
        
        // If using a custom reminder time, validate against the new date
        if reminderType == 5 && customReminderMinutes > 0 {
            // Calculate reminder time based on custom minutes
            let reminderTime = dueDate.addingTimeInterval(-(customReminderMinutes * 60))
            
            // If reminder time is in the past, adjust customReminderMinutes to a sensible value
            if reminderTime < Date() && dueDate > Date() {
                // Calculate maximum safe value (time between now and due date in minutes)
                let maxMinutes = max(5, (dueDate.timeIntervalSince(Date()) / 60) - 1)
                
                // If current setting exceeds maximum, adjust it
                if customReminderMinutes > maxMinutes {
                    customReminderMinutes = maxMinutes
                    print("Adjusted reminder time to \(Int(maxMinutes)) minutes before due date")
                }
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

// Simple category form for quick category creation
struct QuickCategoryForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataController: DataController
    
    @State private var name = ""
    @State private var selectedColorIndex = 0
    
    // Predefined color options
    let predefinedColors = [
        "#3478F6", // Blue
        "#30D158", // Green
        "#FF9F0A", // Orange
        "#FF453A"  // Red
    ]
    
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
        .navigationTitle("New Category")
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
                .disabled(name.isEmpty)
            }
        }
    }
    
    // Save the new category
    private func saveCategory() {
        dataController.addCategory(
            name: name,
            colorHex: predefinedColors[selectedColorIndex]
        )
    }
}
