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
    
    var body: some View {
        List {
            // Task title and completion
            Section {
                HStack {
                    Button(action: toggleCompletion) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(task.isCompleted ? .accentColor : .secondary)
                            .font(.system(size: 22))
                    }
                    .buttonStyle(.plain)
                    
                    Text(task.title ?? "Untitled Task")
                        .font(.headline)
                        .strikethrough(task.isCompleted)
                }
            }
            
            // Task description
            if let description = task.taskDescription, !description.isEmpty {
                Section {
                    Text(description)
                        .foregroundColor(.primary)
                }
            }
            
            // Task metadata and details
            Section {
                if let dueDate = task.dueDate {
                    HStack {
                        Label("Due Date", systemImage: "calendar")
                        Spacer()
                        Text(dueDate, style: .date)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                
                HStack {
                    Label("Priority", systemImage: "flag")
                    Spacer()
                    Text(priorityText)
                        .foregroundColor(priorityColor)
                }
                .accessibilityElement(children: .combine)
                
                if let category = task.category {
                    HStack {
                        Label("Category", systemImage: "folder")
                        Spacer()
                        HStack {
                            Circle()
                                .fill(Color(hex: category.colorHex ?? "#CCCCCC"))
                                .frame(width: 12, height: 12)
                            Text(category.name ?? "")
                        }
                        .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            
            // Timestamps
            Section {
                if let dateCreated = task.dateCreated {
                    HStack {
                        Label("Created", systemImage: "clock")
                        Spacer()
                        Text(dateCreated, style: .date)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                
                if let dateModified = task.dateModified {
                    HStack {
                        Label("Last Modified", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text(dateModified, style: .date)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            
            // Delete task button
            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete Task", systemImage: "trash")
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
                    TaskFormView(mode: .edit(taskId.uuidString))
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
        task.isCompleted = !task.isCompleted
        task.dateModified = Date()
        try? viewContext.save()
    }
}