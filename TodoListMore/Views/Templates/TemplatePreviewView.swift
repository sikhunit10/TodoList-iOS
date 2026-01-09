//
//  TemplatePreviewView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import CoreData
import AmplitudeSwift

struct TemplatePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataController: DataController
    
    let template: TaskTemplate
    
    @State private var baseDate = Date()
    @State private var showingApplyConfirmation = false
    @State private var showingEditForm = false
    
    private var templateTasks: [TemplateTask] {
        template.templateTasksArray
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header info
                    templateHeader
                    
                    // Tasks preview
                    tasksList
                    
                    // Apply button
                    applyButton
                }
                .background(Color(.systemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Template Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !template.isBuiltIn {
                        Button("Edit") {
                            showingEditForm = true
                        }
                        .foregroundColor(Color(hex: "#5D4EFF"))
                    }
                }
            }
            .sheet(isPresented: $showingEditForm) {
                TemplateFormView(mode: .edit(template), onSave: {})
            }
        }
        .onAppear {
            // Track template preview
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.amplitude.track(
                eventType: "template_previewed",
                eventProperties: [
                    "template_name": template.safeName,
                    "template_category": template.safeCategory,
                    "task_count": templateTasks.count
                ]
            )
        }
    }
    
    // MARK: - View Components
    
    private var templateHeader: some View {
        VStack(spacing: 16) {
            // Icon and title
            HStack(spacing: 16) {
                Image(systemName: template.safeIcon)
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: "#5D4EFF"))
                    .frame(width: 60, height: 60)
                    .background(Color(hex: "#5D4EFF").opacity(0.1))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.safeName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(template.safeCategory)
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#5D4EFF"))
                    
                    if !template.safeDescription.isEmpty {
                        Text(template.safeDescription)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            // Base date picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Schedule from")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                DatePicker("Base Date", selection: $baseDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var tasksList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tasks (\(templateTasks.count))")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            LazyVStack(spacing: 8) {
                ForEach(templateTasks, id: \.id) { task in
                    TemplateTaskRowView(task: task, baseDate: baseDate)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var applyButton: some View {
        VStack(spacing: 16) {
            Button(action: {
                showingApplyConfirmation = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("Apply Template")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(hex: "#5D4EFF"))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            Text("This will create \(templateTasks.count) new tasks based on the selected date.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color(.systemGroupedBackground))
        .alert("Apply Template", isPresented: $showingApplyConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Apply") {
                applyTemplate()
            }
        } message: {
            Text("This will create \(templateTasks.count) new tasks. Are you sure you want to continue?")
        }
    }
    
    // MARK: - Actions
    
    private func applyTemplate() {
        guard let templateId = template.id else { 
            print("DEBUG: Template ID is nil")
            return 
        }
        
        print("DEBUG: Applying template with ID: \(templateId) and base date: \(baseDate)")
        let success = dataController.applyTemplate(templateId: templateId, baseDate: baseDate)
        
        if success {
            print("DEBUG: Template applied successfully, dismissing view")
            dismiss()
        } else {
            print("DEBUG: Template application failed")
        }
    }
}

// MARK: - TemplateTaskRowView

struct TemplateTaskRowView: View {
    let task: TemplateTask
    let baseDate: Date
    
    private var calculatedDueDate: Date? {
        guard task.dueDateOffset != 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: Int(task.dueDateOffset), to: baseDate)
    }
    
    private var dueDateText: String {
        guard let dueDate = calculatedDueDate else { return "No due date" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        
        return "\(formatter.string(from: dueDate)) (\(dayFormatter.string(from: dueDate)))"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: task.priorityEnum.color))
                .frame(width: 4, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.safeTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                if !task.safeDescription.isEmpty {
                    Text(task.safeDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    // Priority
                    Label(task.priorityEnum.name, systemImage: task.priorityEnum.icon)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: task.priorityEnum.color))
                    
                    Spacer()
                    
                    // Due date
                    if calculatedDueDate != nil {
                        Text(dueDateText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    TemplatePreviewView(template: TaskTemplate())
        .environmentObject(DataController.shared)
        .environment(\.managedObjectContext, DataController.shared.container.viewContext)
}