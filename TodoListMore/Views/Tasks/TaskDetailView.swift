//
//  TaskDetailView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import CoreData

struct TaskDetailView: View {
    @ObservedObject var task: Task
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataController: DataController
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    // Date formatter for consistent display of dates with time
    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short // Use short date style to save space
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        List {
            // Task title and completion
            Section {
                HStack(spacing: 12) {
                    Button(action: toggleCompletion) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(task.isCompleted ? .accentColor : .secondary)
                            .font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                    
                    Text(task.title ?? "Untitled Task")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                }
                .padding(.vertical, 8)
            }
            
            // Task description
            if let description = task.taskDescription, !description.isEmpty {
                Section {
                    if let url = description.firstURL() {
                        Link(description, destination: url)
                            .foregroundColor(.blue)
                    } else {
                        Text(description)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            // Task metadata and details
            Section {
                HStack {
                    Label {
                        Text("Due Date")
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if let dueDate = task.dueDate {
                        // Show both date and time
                        Text("\(dueDate, formatter: Self.dateTimeFormatter)")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    } else {
                        Text("None")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .opacity(0.7)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                // Recurrence rule display
                HStack {
                    Label {
                        Text("Repeats")
                    } icon: {
                        Image(systemName: "repeat")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(task.recurrenceRuleEnum.name)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                
                HStack {
                    Label {
                        Text("Priority")
                    } icon: {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(priorityText)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(priorityColor.opacity(0.15))
                        .foregroundColor(priorityColor)
                        .cornerRadius(8)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                
                // Always show category (either actual category or "Uncategorized")
                HStack {
                    Label {
                        Text("Category") 
                    } icon: {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        if let category = task.category {
                            Circle()
                                .fill(Color(hex: category.colorHex ?? "#CCCCCC"))
                                .frame(width: 14, height: 14)
                            Text(category.name ?? "")
                                .bold()
                        } else {
                            Circle()
                                .fill(Color(hex: "#5D4EFF"))
                                .frame(width: 14, height: 14)
                            Text("Uncategorized")
                                .bold()
                        }
                    }
                    .foregroundColor(.secondary)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
            
            // Timestamps
            Section(header: Text("History")) {
                if let dateCreated = task.dateCreated {
                    HStack {
                        Label {
                            Text("Created")
                        } icon: {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(dateCreated, formatter: Self.dateTimeFormatter)")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
                
                if let dateModified = task.dateModified {
                    HStack {
                        Label {
                            Text("Last Modified")
                        } icon: {
                            Image(systemName: "pencil.circle")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(dateModified, formatter: Self.dateTimeFormatter)")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
            
            // Delete task button
            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Delete Task", systemImage: "trash")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                if let taskId = task.id {
                    TaskFormView(mode: .edit(taskId.uuidString), onSave: {
                        // Refresh both the task and all context objects
                        viewContext.refresh(task, mergeChanges: true)
                        viewContext.refreshAllObjects()
                    })
                }
            }
        }
        .alert("Delete Task", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                dataController.delete(task)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this task? This action cannot be undone.")
        }
    }
    
    private var priorityText: String {
        let priorityValue = task.priority
        switch priorityValue {
        case 1: return "Low"
        case 2: return "Medium"
        case 3: return "High"
        default: return "Low"
        }
    }
    
    private var priorityColor: Color {
        let priorityValue = task.priority
        switch priorityValue {
        case 1: return .blue
        case 2: return .orange
        case 3: return .red
        default: return .blue
        }
    }
    
    private func toggleCompletion() {
        let currentValue = task.isCompleted
        let rule = task.recurrenceRuleEnum
        // Handle recurring tasks: schedule next occurrence instead of marking complete
        if !currentValue && rule != .none {
            if let dueDate = task.dueDate {
                let calendar = Calendar.current
                var nextDate: Date?
                switch rule {
                case .daily:
                    nextDate = calendar.date(byAdding: .day, value: 1, to: dueDate)
                case .weekly:
                    nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: dueDate)
                case .monthly:
                    nextDate = calendar.date(byAdding: .month, value: 1, to: dueDate)
                case .yearly:
                    nextDate = calendar.date(byAdding: .year, value: 1, to: dueDate)
                default:
                    break
                }
                if let next = nextDate {
                    task.dueDate = next
                }
            }
            task.dateModified = Date()
            try? viewContext.save()
            if dataController.hasReminderSupport {
                task.scheduleReminder()
            }
            // Refresh UI to reflect new due date
            viewContext.refreshAllObjects()
            return
        }
        // Non-recurring: toggle completion as usual
        task.isCompleted = !currentValue
        task.dateModified = Date()
        try? viewContext.save()
        // Ensure the change is immediately visible in other views
        viewContext.refreshAllObjects()
    }
}